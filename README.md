# CVMFS Tarball Builder

This repository provides a utility to build Python-based software tarballs, including their runtime dependencies and optional configuration files, for deployment in [CVMFS](https://cernvm.cern.ch/fs/).

## Overview

The core functionality revolves around:
- Creating self-contained Python environments (virtualenvs) using `pyenv`.
- Installing a specific version of a Python package (e.g. `rucio-clients`) and its dependencies.
- Collecting the relevant binaries and Python libraries into a standardized directory layout (`bin/`, `lib/`, and optionally `etc/`).
- Adapting executable scripts for runtime portability by injecting a custom shebang referencing the `RUCIO_PYTHONBIN` environment variable.
- Producing a compressed tarball suitable for CVMFS deployment.

This setup is general and can be extended to support other Python-based command-line tools or scientific software requiring reproducible environments.

## Repository Structure

- `make_tarball.sh`: Shell script that drives the tarball generation process.
- `setup.*`: Setup scripts sourced at runtime to activate the environment (optional).
- `package-<version>.tar.gz`: Output tarball artifact.

## Key Features

- Support for multiple Python versions (e.g. 3.9–3.12).
- Use of `pyenv` and `pyenv-virtualenv` for isolated and versioned environments.
- No system-wide dependencies beyond Python and pip.
- Scripts rewritten with portable shebangs for flexibility across environments.

## Example Use Case

An example script `rucio/make_tarball.sh` is provided to generate tarballs for the `rucio-clients` package. It:

- Builds virtual environments for selected Python versions.
- Installs the specified version of the `rucio-clients` package.
- Assembles all necessary binaries and libraries.
- Produces a versioned tarball for deployment.

The resulting tarball can then be extracted into a CVMFS repository or similar shared environment.

## Requirements

- `pyenv` and `pyenv-virtualenv` installed and available in your shell.
- Python versions installed via `pyenv` (e.g. `pyenv install 3.11.8`).
- Optional configuration files or runtime scripts as needed by your package.

## Deployment Notes

When deploying the tarballs:

- Set the `RUCIO_PYTHONBIN` (or your tool’s equivalent) environment variable to the target Python binary within the tarball.
- Ensure CVMFS write access and packaging policies are respected (e.g. no user-specific paths).
- Use a site-wide setup script (`setup.sh`) to export paths and environment variables, ensuring a consistent setup across machines.


## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.