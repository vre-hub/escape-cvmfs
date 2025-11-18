#!/usr/bin/env bash
# Copyright European Organization
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                       http://www.apache.org/licenses/LICENSE-2.0
#
# Authors:
# - Giovanni Guerrieri, <giovanni.guerrieri@cern.ch>, 2025
# - Enrique Garcia Garcia, <enrique.garcia.garcia@cern.ch>, 2025
# - ChatGPT-5.1 Codex, 2025
#
# This script mirrors the structure of the Rucio packaging helpers to build a
# tarball that layers the ATLAS OpenMagic analysis environment inside CVMFS.
# The package list is derived from the public environment description at
# https://raw.githubusercontent.com/atlas-outreach-data-tools/notebooks-collection-opendata/refs/heads/master/binder/environment.yml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define environment and Python versions
ATLASOPENMAGIC_VERSION=analysis-2025.11
BASE_PYTHON_VERSION=3.11.9
PYTHON_VERSIONS=("3.11.8" "3.11.9")

EXPORT_ENV_NAME=atlasopenmagic

# Non-pip dependencies listed in the upstream environment file. We surface them
# to make it clear they are expected to be layered in separately (e.g. via
# CVMFS-provided system packages or a parent image).
EXTERNAL_DEPENDENCIES=(
  "libmamba>=2.0.4"
  "root_base>=6.32.2"
)

# Pip packages gathered from the upstream environment.yml pip subsection
PIP_PACKAGES=(
  "aiohttp>=3.9.5"
  "atlasopenmagic>=1.2.0"
  "awkward>=2.6.7"
  "awkward-pandas>=2023.8.0"
  "coffea~=0.7.0"
  "fsspec>=2025.7.0"
  "hist>=2.8.0"
  "ipykernel>=6.29.5"
  "jupyter>=1.0.0"
  "lmfit>=1.3.2"
  "matplotlib>=3.9.1"
  "metakernel>=0.30.2"
  "notebook<7"
  "numpy>=1.26.4"
  "pandas>=2.2.2"
  "papermill>=2.6.0"
  "pip>=24.2"
  "scikit-learn>=1.5.1"
  "uproot>=5.3.10"
  "uproot3>=3.14.4"
  "fsspec-xrootd>=0.5.1"
  "jupyterlab_latex~=3.1.0"
  "vector>=1.4.1"
)

# Set locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Helper to show warnings without aborting
warn () {
  echo "WARNING: $*" >&2
}

# Function to install packages for a specific Python version
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

  for package in "${PIP_PACKAGES[@]}"; do
    if ! pip install "$package"; then
      warn "Failed to install $package for Python $version"
    fi
  done
  pip freeze

  echo "$version: Consolidating site-packages"
  local lib_root
  lib_root="$(pyenv virtualenv-prefix)/envs/${env_name}/lib/python${py_mm}"
  if [ ! -d "$lib_root" ]; then
    warn "Expected lib directory $lib_root missing"
  else
    mkdir -p "lib/python${py_mm}"
    rsync -a "$lib_root"/ "lib/python${py_mm}/"
  fi
}

echo "General: The following dependencies must be provided outside pip:"
for dep in "${EXTERNAL_DEPENDENCIES[@]}"; do
  echo "  - $dep"
done

# Prepare workspace
BUILD_ROOT="$SCRIPT_DIR/$ATLASOPENMAGIC_VERSION"
mkdir -p "$BUILD_ROOT"
cd "$BUILD_ROOT"
mkdir -p lib

# Install for each Python version
for version in "${PYTHON_VERSIONS[@]}"; do
  run_install "$version"
done

echo "General: Copying in bin/"
pyenv local "${EXPORT_ENV_NAME}-py${BASE_PYTHON_VERSION}"
mkdir -p bin
cp -R "$(pyenv virtualenv-prefix)/envs/${EXPORT_ENV_NAME}-py${BASE_PYTHON_VERSION}/bin/." bin/

echo "General: Cleaning bin/"
if [ -f "$SCRIPT_DIR/common/rm_from_bin_folder.txt" ]; then
  echo " - $(cat $SCRIPT_DIR/common/rm_from_bin_folder.txt)"
  while IFS= read -r file; do
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
    printf '"exec" "$ATLASOPENMAGIC_PYTHONBIN" "-u" "-Wignore" "$0" "$@"\n'
    tail -n +2 "$script" 2>/dev/null || true
  } > "$tmpfile"
  mv "$tmpfile" "$script"
  chmod +x "$script"
done

echo "General: Copying setup script"
cp -R "$SCRIPT_DIR"/common/setup_scripts/setup* .

echo "General: Creating archive"
tar zcf "$SCRIPT_DIR"/atlasopenmagic-${ATLASOPENMAGIC_VERSION}.tar.gz *
echo " - $(ls -la "$SCRIPT_DIR"/atlasopenmagic-${ATLASOPENMAGIC_VERSION}.tar.gz)"

echo "General: DONE!"

