# Celebi on CVMFS

This directory builds and deploys a self-contained CelebiChrono Python 3.11
runtime under `/cvmfs/sw.escape.eu/celebi/<version>/`.

## Build

The normal build is performed by the `Build Celebi Tarball` GitHub Actions
workflow. For a local source checkout:

```bash
CELEBI_SOURCE_DIR=/path/to/Celebi ./make_tarball.sh
```

The output is `celebi-<version>-<commit>.tar.gz` plus a SHA-256 checksum. The
version is read from the source checkout's `pyproject.toml`; the commit suffix
makes the CVMFS release label unambiguous while the project is in beta.

## Deploy

On the CVMFS publisher, deploy the GitHub Actions artifact:

```bash
./utils/celebi-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID>
```

Use `--force` only when intentionally replacing the same release label.

## Use

```bash
source /cvmfs/sw.escape.eu/celebi/latest/setup.sh
celebi-cli --help
```

The setup script prefers LCG 107's Python 3.11 and falls back to a compatible
`python3.11` on `PATH`.
