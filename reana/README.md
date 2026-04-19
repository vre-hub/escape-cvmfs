# reana-client tarball builder

Builds a self-contained `reana-client` tarball for deployment on CVMFS.

## Build

### Prerequisites

1. Install system build dependencies:

```bash
# RHEL/Alma/Rocky
dnf install make gcc patch zlib-devel bzip2 bzip2-devel readline-devel \
  sqlite sqlite-devel openssl-devel tk-devel libffi-devel xz-devel \
  libuuid-devel gdbm-libs libnsl2 rsync

# Debian/Ubuntu
apt-get install make gcc zlib1g-dev libbz2-dev libreadline-dev \
  libsqlite3-dev libssl-dev tk-dev libffi-dev liblzma-dev uuid-dev \
  libgdbm-dev libnsl-dev git curl rsync unzip
```

2. Install [pyenv](https://github.com/pyenv/pyenv?tab=readme-ov-file#automatic-installer):

```bash
curl https://pyenv.run | bash
```

### Build the tarball

Build with the default version (0.9.3):

```bash
./make_tarball.sh
```

Build a specific version:

```bash
./make_tarball.sh 0.9.2
```

Or via environment variable:

```bash
REANA_VERSION=0.9.2 ./make_tarball.sh
```

The script will install Python 3.11.9 and 3.12.2 via pyenv, create virtualenvs, and produce `reana-client-<VERSION>.tar.gz`.

### CI

The GitHub Actions workflow triggers on pushes to `reana/**` on `main`. You can also trigger it manually via `workflow_dispatch` and optionally specify a custom `reana_version`.

## Deploy to CVMFS

```bash
./utils/reana-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID> [REANA_VERSION]
```

Use `--force` to overwrite an existing version:

```bash
./utils/reana-cvmfs-updater.sh --force <GITHUB_TOKEN> <ARTIFACT_ID> 0.9.3
```

## Usage

After deployment, users source the setup script:

```bash
export REANA_HOME=/cvmfs/sw.escape.eu/reana/0.9.3
source $REANA_HOME/setup-minimal.sh

# Then configure the REANA server you want to talk to
export REANA_SERVER_URL=https://reana.cern.ch
export REANA_ACCESS_TOKEN=<your-token>
```
