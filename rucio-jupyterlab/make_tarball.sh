#!/usr/bin/env bash
# Copyright European Organization for Nuclear Research (CERN)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# You may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#                       http://www.apache.org/licenses/LICENSE-2.0
#
# Authors:
# - Giovanni Guerrieri, <giovanin.guerrieri@cern.ch>, 2025
# - Enrique Garcia Garcia, <enrique.garcia.garcia@cern.ch>, 2025

# Define Rucio and Python versions
RUCIO_EXT_VERSION=1.4.0
RUCIO_CLIENTS_VERSION=35.8.0
BASE_PYTHON_VERSION=3.11.8
PYTHON_VERSIONS=("3.11.8" "3.12.2") # space-separated list of python versions

# Set locale settings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Function to install Rucio clients and dependencies for a specific Python version
run_install () {
  echo "$1: Loading virtual environment" 
  export RUCIO_EXT_VERSION=$RUCIO_EXT_VERSION
  pyenv install --force $1  # Ensure the specified Python version is installed
  pyenv virtualenv --force $1 rucio-jlab-ext-py$1  # Create or overwrite virtual environment
  pyenv local rucio-jlab-ext-py$1  # Set the local Python version
  python --version  # Display the Python version

  echo $PWD
  echo "$1: Installing dependencies"
  pip install pip --upgrade  # Upgrade pip
  pip install -U setuptools  # Upgrade setuptools
  pip install rucio-jupyterlab=="$RUCIO_EXT_VERSION"  # Install Rucio jlab - script run inside cd $RUCIO_EXT_VERSION
  pip install rucio-clients=="$RUCIO_CLIENTS_VERSION"
  pip install argcomplete  # Install argcomplete dependency separately
  pip freeze  # Display installed packages

  echo "$1: Bringing things together"
  # Ensure dogpile package is properly initialized
  DOGPILE_PATH=$(pyenv virtualenv-prefix)/envs/rucio-jlab-ext-py$1/lib/python${1%*.*}/site-packages/dogpile
  if [ -d "$DOGPILE_PATH" ]; then
    touch "$DOGPILE_PATH/__init__.py"
  else
    echo "Warning: Dogpile package not found at $DOGPILE_PATH"
  fi
  # Copy the Python library files to the `lib` directory
  cp -r $(pyenv virtualenv-prefix)/envs/rucio-jlab-ext-py$1/lib/python${1%*.*}/ lib/
}

# Create the main directory for the tarball
mkdir $RUCIO_EXT_VERSION
cd $RUCIO_EXT_VERSION
mkdir lib  # Create a directory to store Python libraries

# Run the installation process for each Python version
for version in ${PYTHON_VERSIONS[@]}; do
  run_install "$version"
done

echo "General: Copying in bin/"
# Set the base Python version as the local version
pyenv local rucio-jlab-ext-py$BASE_PYTHON_VERSION
mkdir bin  # Create a directory for executable scripts
# Copy Rucio and Jupyter exntesion executables to the `bin` directory
cp -r $(pyenv virtualenv-prefix)/envs/rucio-jlab-ext-py$BASE_PYTHON_VERSION/bin/* bin/
# Remove the pyenv, python and pip default executables related with the creation of the pyenv
# An error 'sed: couldn't edit bin/__pycache__: not a regular file' would appear
for file in `cat ../common/rm_from_bin_folder.txt`; do
  rm -f bin/$file
done

echo "General: Adapting bin scripts"
# Modify the shebang lines of the copied scripts to use the correct Python interpreter
# Set up in the setup-minimal.sh within the common/setup_scrupts folder
for script in `ls bin/`; do
  sed -i '1c\
#!/bin/bash\n\
# -*- coding: utf-8 -*-\n\
"exec" "$RUCIO_PYTHONBIN" "-u" "-Wignore" "$0" "$@"\n' "bin/$script"
done

echo "General: Copying setup script"
# Copy the setup script into the package
cp -r ../common/setup_scripts/setup* .

echo "General: Creating archive"
# Create a tarball of the Rucio clients
tar zcf ../rucio-jupyterlab-$RUCIO_EXT_VERSION.tar.gz *

echo "General: DONE!"

# Provide the command to upload the tarball to a remote server
# echo "scp rucio-jupyterlab-$RUCIO_EXT_VERSION.tar.gz ${USER}@lxplus:~/public/"
