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
# CVMFS copy of the container image hdemule/rucio-clients-rbac:<first 12 characters of FORK_SHA>.
#
# The image is: rucio/rucio-clients:release-41.1.1
#               + the client wheel of the fork (built from one commit, see below)
#               + rucio.cfg and tls-ca-bundle.pem (and the tutorial repository).
# This script makes the same client wheel, the same dependency versions
# (constraints-image.txt, if present), the same rucio.cfg and the same CA bundle.
# It reuses ../rucio/make_tarball.sh.

set -euo pipefail

# ../rucio/make_tarball.sh runs pip through pyenv. In an active virtualenv, "pip" would be the one of
# the virtualenv and the build would install packages into it.
if [ -n "${VIRTUAL_ENV:-}" ]; then
  echo "ERROR: a virtualenv is active ($VIRTUAL_ENV). Run 'deactivate' and start this script again." >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORK_REPO="${FORK_REPO:-https://github.com/hdemule/rucio.git}"
# Full commit of the fork. The image tag is its first 12 characters.
FORK_SHA="${FORK_SHA:-7273054bfdc4bf7f1062b36673695ba169aeb38f}"
[[ "$FORK_SHA" =~ ^[0-9a-f]{40}$ ]] || { echo "ERROR: FORK_SHA must be a full commit (40 hexadecimal characters), not a branch or a tag" >&2; exit 1; }
SHORT="${FORK_SHA:0:12}"
# Same version string as in the image (build argument PACKAGE_VERSION of the Dockerfile).
PACKAGE_VERSION="${PACKAGE_VERSION:-41.0.0rc1+rbac.${SHORT}}"
# Folder name on CVMFS: /cvmfs/sw.escape.eu/rucio/<LABEL>
LABEL="${LABEL:-41.1.1-rbac-${SHORT}}"
# Fingerprint of the wheel in the image: sha256 of the sorted RECORD lines (without the RECORD line itself).
# It is checked for the default commit only.
if [ "$FORK_SHA" = 7273054bfdc4bf7f1062b36673695ba169aeb38f ]; then
  EXPECTED_RECORD_SHA256="${EXPECTED_RECORD_SHA256:-5679a8a865a7b3322d1653873e392b277809ce243d593eebe237ddcf6102fe9b}"
else
  EXPECTED_RECORD_SHA256="${EXPECTED_RECORD_SHA256:-}"
fi

WORK_DIR="$SCRIPT_DIR/build"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "=== Fetching $FORK_REPO @ $FORK_SHA"
git init -q "$WORK_DIR/src"
git -C "$WORK_DIR/src" fetch -q --depth 1 "$FORK_REPO" "$FORK_SHA"
git -C "$WORK_DIR/src" checkout -q FETCH_HEAD
[ "$(git -C "$WORK_DIR/src" rev-parse HEAD)" = "$FORK_SHA" ] || { echo "ERROR: fetched commit is not $FORK_SHA" >&2; exit 1; }

echo "=== Building the client wheel as in the image Dockerfile (version $PACKAGE_VERSION)"
(
  cd "$WORK_DIR/src"
  printf "IS_FINAL = False\nVERSION = '%s'\nBRANCH_NICK = 'rbac'\nREVISION_ID = '%s'\nREVNO = '0'\n" \
    "$PACKAGE_VERSION" "$FORK_SHA" > lib/rucio/vcsversion.py
  python3 -m venv "$WORK_DIR/buildenv"
  "$WORK_DIR/buildenv/bin/pip" install -q build
  PATH="$WORK_DIR/buildenv/bin:$PATH" bash tools/build_sdist_wheel.sh clients
)
WHEEL="$(ls "$WORK_DIR"/src/dist/rucio_clients-*.whl)"

if [ -n "$EXPECTED_RECORD_SHA256" ]; then
  got="$(python3 - "$WHEEL" <<'EOF'
import hashlib, sys, zipfile
z = zipfile.ZipFile(sys.argv[1])
rec = next(n for n in z.namelist() if n.endswith(".dist-info/RECORD"))
lines = sorted(l for l in z.read(rec).decode().splitlines() if l and "RECORD" not in l)
print(hashlib.sha256(("\n".join(lines) + "\n").encode()).hexdigest())
EOF
)"
  [ "$got" = "$EXPECTED_RECORD_SHA256" ] \
    || { echo "ERROR: the wheel differs from the wheel in the image ($got)" >&2; exit 1; }
  echo "    wheel content is identical to the wheel in the image"
fi

echo "=== Staging extra files"
EXTRA="$WORK_DIR/extra"
cp -R "$SCRIPT_DIR/extra" "$EXTRA"
{
  echo "$FORK_REPO@$FORK_SHA"
  echo "package version: $PACKAGE_VERSION"
  echo "copy of image:   hdemule/rucio-clients-rbac:$SHORT"
} > "$EXTRA/FORK_COMMIT"

# One hashed CA directory for X509_CERT_DIR, made from the CA bundle of the image.
# The Rucio servers use a public CA (Sectigo) and EOS uses the CERN Grid CA; the bundle holds both.
CERT_DIR="$EXTRA/etc/certificates"
mkdir -p "$CERT_DIR"
python3 - "$EXTRA/etc/tls-ca-bundle.pem" "$CERT_DIR" <<'EOF'
import pathlib, re, sys
bundle, out = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
pems = re.findall(r"-----BEGIN CERTIFICATE-----.+?-----END CERTIFICATE-----", bundle.read_text(), re.S)
for i, pem in enumerate(pems):
    (out / f"ca-{i:03d}.pem").write_text(pem + "\n")
print(f"    {len(pems)} CA certificates")
EOF
openssl rehash "$CERT_DIR" > /dev/null

echo "=== Building the tarball $LABEL"
if [ -f "$SCRIPT_DIR/constraints-image.txt" ]; then
  cp "$SCRIPT_DIR/constraints-image.txt" "$EXTRA/pip-constraints-image.txt"
  export PIP_CONSTRAINT="$SCRIPT_DIR/constraints-image.txt"
  echo "    dependency versions pinned to the image (constraints-image.txt)"
else
  echo "    WARNING: no constraints-image.txt; dependencies are the newest versions"
fi
RUCIO_CLIENTS_SPEC="$WHEEL" EXTRA_FILES_DIR="$EXTRA" \
  "$SCRIPT_DIR/../rucio/make_tarball.sh" "$LABEL"

mv "$SCRIPT_DIR/../rucio/rucio-clients-${LABEL}.tar.gz" "$SCRIPT_DIR/"
python3 - "$SCRIPT_DIR/rucio-clients-${LABEL}.tar.gz" > "$SCRIPT_DIR/rucio-clients-${LABEL}.tar.gz.sha256" <<'EOF'
import hashlib, os, sys
p = sys.argv[1]
print(hashlib.sha256(open(p, "rb").read()).hexdigest() + "  " + os.path.basename(p))
EOF
cat "$SCRIPT_DIR/rucio-clients-${LABEL}.tar.gz.sha256"
echo "=== DONE: $SCRIPT_DIR/rucio-clients-${LABEL}.tar.gz"
