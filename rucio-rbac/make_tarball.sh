#!/usr/bin/env bash
# Copyright European Organization for Nuclear Research (CERN)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# You may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                       http://www.apache.org/licenses/LICENSE-2.0
#
# Authors:
# - Giovanni Guerrieri, <giovanni.guerrieri@cern.ch>, 2026
#
# Builds the RBAC fork of rucio-clients (rucio role ...) with the configuration of the
# rbac-test instance, for the Rucio tutorial in SWAN. Reuses ../rucio/make_tarball.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORK_REPO="${FORK_REPO:-https://github.com/hdemule/rucio.git}"
FORK_REF="${FORK_REF:-rbac}"

WORK_DIR="$SCRIPT_DIR/build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "=== Cloning $FORK_REPO@$FORK_REF ==="
git clone -q --depth 1 -b "$FORK_REF" "$FORK_REPO" "$WORK_DIR/src"
FORK_SHA="$(git -C "$WORK_DIR/src" rev-parse --short HEAD)"
BASE_VERSION="$(sed -n "s/^VERSION = '\(.*\)'/\1/p" "$WORK_DIR/src/lib/rucio/vcsversion.py")"
RUCIO_VERSION="${BASE_VERSION}-rbac"
echo "    fork commit: $FORK_SHA, label: $RUCIO_VERSION"

echo "=== Building the client wheel ==="
(
  cd "$WORK_DIR/src"
  cp MANIFEST.client.in MANIFEST.in
  cp pyproject.client.toml pyproject.toml
  python -m pip install -q build certifi
  python -m build --wheel --outdir "$WORK_DIR/dist"
)
WHEEL="$(ls "$WORK_DIR"/dist/rucio_clients-*.whl)"

echo "=== Staging extra files ==="
EXTRA="$WORK_DIR/extra"
cp -R "$SCRIPT_DIR/extra" "$EXTRA"
echo "$FORK_REPO@$FORK_SHA" > "$EXTRA/FORK_COMMIT"

# One hashed CA directory for X509_CERT_DIR: the Rucio servers use a public CA (Sectigo) and
# EOS uses the CERN Grid CA, and X509_CERT_DIR wins over [client] ca_cert in the Rucio client.
CERT_DIR="$EXTRA/etc/certificates"
mkdir -p "$CERT_DIR"
python - "$CERT_DIR" <<'EOF'
import sys, pathlib, re, certifi
out = pathlib.Path(sys.argv[1])
pems = re.findall(r"-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----", pathlib.Path(certifi.where()).read_text(), re.S)
for i, pem in enumerate(pems):
    (out / f"mozilla-{i:03d}.pem").write_text(pem + "\n")
EOF
curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Root%20Certification%20Authority%202.crt' \
  | openssl x509 -inform DER -out "$CERT_DIR/cern-root-ca-2.pem"
curl -fsSL 'https://cafiles.cern.ch/cafiles/certificates/CERN%20Grid%20Certification%20Authority(1).crt' \
  | openssl x509 -out "$CERT_DIR/cern-grid-ca.pem"
openssl rehash "$CERT_DIR"

echo "=== Building the tarball ==="
RUCIO_CLIENTS_SPEC="$WHEEL" EXTRA_FILES_DIR="$EXTRA" \
  "$SCRIPT_DIR/../rucio/make_tarball.sh" "$RUCIO_VERSION"

mv "$SCRIPT_DIR/../rucio/rucio-clients-${RUCIO_VERSION}.tar.gz" "$SCRIPT_DIR/"
echo "=== DONE: $SCRIPT_DIR/rucio-clients-${RUCIO_VERSION}.tar.gz ==="
