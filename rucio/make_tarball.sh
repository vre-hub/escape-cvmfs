#!/usr/bin/env bash
# Copyright European Organization for Nuclear Research (CERN)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# You may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                       http://www.apache.org/licenses/LICENSE-2.0
#
# Authors:
# - Giovanni Guerrieri, <giovanni.guerrieri@cern.ch>, 2025

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Defaults — override via CLI or environment
RUCIO_VERSION="${1:-${RUCIO_VERSION:-38.3.0}}"
BASE_PYTHON_VERSION="${BASE_PYTHON_VERSION:-3.11.9}"
PYTHON_VERSIONS=("3.11.9" "3.12.2")

EXPORT_ENV_NAME=rucio

# Set locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

warn () {
  echo "WARNING: $*" >&2
}

# Install rucio-clients into a pyenv virtualenv and consolidate site-packages
run_install () {
  local version="$1"
  local env_name="${EXPORT_ENV_NAME}-py${version}"
  local py_mm="${version%.*}"

  echo "$version: Loading virtual environment"
  pyenv install -s "$version"
  pyenv virtualenv --force "$version" "$env_name"
  pyenv local "$env_name"
  python --version

  echo "$version: Installing dependencies"
  pip install --upgrade pip
  pip install -U setuptools wheel
  pip install "rucio-clients==${RUCIO_VERSION}"
  pip install argcomplete
  pip freeze

  echo "$version: Consolidating site-packages"
  local lib_root
  lib_root="$(pyenv virtualenv-prefix)/envs/${env_name}/lib/python${py_mm}"

  # Ensure dogpile namespace package is properly initialized
  local dogpile_path="${lib_root}/site-packages/dogpile"
  if [ -d "$dogpile_path" ]; then
    touch "$dogpile_path/__init__.py"
  else
    warn "Dogpile package not found at $dogpile_path"
  fi

  if [ ! -d "$lib_root" ]; then
    warn "Expected lib directory $lib_root missing"
  else
    mkdir -p "lib/python${py_mm}"
    rsync -a "$lib_root"/ "lib/python${py_mm}/"
  fi
}

# Prepare workspace
BUILD_ROOT="$SCRIPT_DIR/$RUCIO_VERSION"
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"
mkdir -p lib

echo "=== Building rucio-clients $RUCIO_VERSION ==="
echo "    Python versions: ${PYTHON_VERSIONS[*]}"
echo "    Base Python:     $BASE_PYTHON_VERSION"

# Install for each Python version
for version in "${PYTHON_VERSIONS[@]}"; do
  run_install "$version"
done

echo "General: Copying in bin/"
pyenv local "${EXPORT_ENV_NAME}-py${BASE_PYTHON_VERSION}"
mkdir -p bin
cp "$(pyenv virtualenv-prefix)/envs/${EXPORT_ENV_NAME}-py${BASE_PYTHON_VERSION}/bin/rucio" bin/
cp "$(pyenv virtualenv-prefix)/envs/${EXPORT_ENV_NAME}-py${BASE_PYTHON_VERSION}/bin/rucio-admin" bin/
cp "$(pyenv virtualenv-prefix)/envs/${EXPORT_ENV_NAME}-py${BASE_PYTHON_VERSION}/bin/register-python-argcomplete" bin/

echo "General: Cleaning bin/"
if [ -f "$SCRIPT_DIR/common/rm_from_bin_folder.txt" ]; then
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    echo " - $file"
    rm -f "bin/$file"
  done < "$SCRIPT_DIR/common/rm_from_bin_folder.txt"
fi

echo "General: Adapting bin scripts"
for script in bin/*; do
  [ -f "$script" ] || continue
  tmpfile="$(mktemp)"
  {
    printf '#!/bin/bash\n'
    printf '# -*- coding: utf-8 -*-\n'
    printf '"exec" "$RUCIO_PYTHONBIN" "-u" "-Wignore" "$0" "$@"\n'
    tail -n +2 "$script" 2>/dev/null || true
  } > "$tmpfile"
  mv "$tmpfile" "$script"
  chmod +x "$script"
done

echo "General: Copying setup scripts"
cp -R "$SCRIPT_DIR"/common/setup_scripts/setup* .

echo "General: Creating archive"
tar zcf "$SCRIPT_DIR/rucio-clients-${RUCIO_VERSION}.tar.gz" *
echo " - $(ls -la "$SCRIPT_DIR/rucio-clients-${RUCIO_VERSION}.tar.gz")"

echo "General: DONE!"
