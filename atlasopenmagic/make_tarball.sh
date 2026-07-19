#!/usr/bin/env bash
# Copyright European Organization
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                       http://www.apache.org/licenses/LICENSE-2.0
#
# Authors:
# - Giovanni Guerrieri, <giovanni.guerrieri@cern.ch>, 2025-2026
# - Enrique Garcia Garcia, <enrique.garcia.garcia@cern.ch>, 2025
#
# Builds a tarball that layers the atlasopenmagic ("atom") package on top of
# any existing Python >= 3.10 environment via PYTHONPATH. Only atlasopenmagic
# and its runtime dependencies (pyyaml, requests, tqdm) are shipped — the full
# analysis stack (ROOT, coffea, jupyter, ...) is expected to come from the
# hosting image/environment.
#
# Usage:
#   ./make_tarball.sh [ATLASOPENMAGIC_VERSION]
#
# If no version is given, the latest release on PyPI is used. Every Python
# interpreter in PYTHON_VERSIONS must be available on PATH as pythonX.Y
# (in CI this is provided by actions/setup-python).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Python minor versions to provide site-packages for. atlasopenmagic requires
# python >= 3.10. Override with e.g. PYTHON_VERSIONS="3.11 3.12".
PYTHON_VERSIONS=(${PYTHON_VERSIONS:-3.10 3.11 3.12 3.13 3.14})

ATLASOPENMAGIC_VERSION="${1:-${ATLASOPENMAGIC_VERSION:-}}"

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export PIP_DISABLE_PIP_VERSION_CHECK=1

warn () {
  echo "WARNING: $*" >&2
}

# Resolve the latest PyPI release when no version was requested
if [ -z "$ATLASOPENMAGIC_VERSION" ]; then
  ATLASOPENMAGIC_VERSION="$(curl -fsSL https://pypi.org/pypi/atlasopenmagic/json \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])')"
  echo "General: No version requested, using latest PyPI release: $ATLASOPENMAGIC_VERSION"
fi

BUILD_ROOT="$SCRIPT_DIR/build-${ATLASOPENMAGIC_VERSION}"
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT/lib" "$BUILD_ROOT/bin"

for version in "${PYTHON_VERSIONS[@]}"; do
  pybin="python${version}"
  # command -v alone is not enough: pyenv shims can resolve but fail to run
  if ! "$pybin" --version >/dev/null 2>&1; then
    warn "$pybin not usable on PATH - skipping Python $version"
    continue
  fi

  echo "$version: Installing atlasopenmagic==${ATLASOPENMAGIC_VERSION}"
  sitepkgs="$BUILD_ROOT/lib/python${version}/site-packages"
  mkdir -p "$sitepkgs"
  "$pybin" -m pip install --no-cache-dir --target "$sitepkgs" \
    "atlasopenmagic==${ATLASOPENMAGIC_VERSION}"

  # pip --target drops console scripts into <target>/bin; merge them into the
  # top-level bin so they can be rewritten to use $ATLASOPENMAGIC_PYTHONBIN
  if [ -d "$sitepkgs/bin" ]; then
    cp -R "$sitepkgs/bin/." "$BUILD_ROOT/bin/"
    rm -rf "$sitepkgs/bin"
  fi
done

# Fail loudly if nothing was built (e.g. no interpreter was found)
if ! find "$BUILD_ROOT/lib" -mindepth 2 -maxdepth 2 -name site-packages | grep -q .; then
  echo "ERROR: No site-packages were produced - check that pythonX.Y binaries are on PATH" >&2
  exit 1
fi

cd "$BUILD_ROOT"

echo "General: Cleaning bin/"
if [ -f "$SCRIPT_DIR/common/rm_from_bin_folder.txt" ]; then
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    echo " - $file"
    rm -f "bin/$file"
  done < "$SCRIPT_DIR/common/rm_from_bin_folder.txt"
fi

echo "General: Adapting bin scripts to use \$ATLASOPENMAGIC_PYTHONBIN"
for script in bin/*; do
  [ -f "$script" ] || continue
  tmpfile="$(mktemp)"
  {
    printf '#!/bin/bash\n'
    printf '# -*- coding: utf-8 -*-\n'
    printf '"exec" "$ATLASOPENMAGIC_PYTHONBIN" "-u" "-Wignore" "$0" "$@"\n'
    tail -n +2 "$script" 2>/dev/null || true
  } > "$tmpfile"
  mv "$tmpfile" "$script"
  chmod +x "$script"
done

echo "General: Copying setup scripts"
cp -R "$SCRIPT_DIR"/common/setup_scripts/setup* .

echo "${ATLASOPENMAGIC_VERSION}" > VERSION

echo "General: Creating archive"
tar zcf "$SCRIPT_DIR/atlasopenmagic-${ATLASOPENMAGIC_VERSION}.tar.gz" .
echo " - $(ls -la "$SCRIPT_DIR/atlasopenmagic-${ATLASOPENMAGIC_VERSION}.tar.gz")"

echo "General: DONE!"
