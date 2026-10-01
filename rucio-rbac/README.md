# rucio-clients (RBAC fork) tarball builder

Builds the RBAC fork of `rucio-clients` (`hdemule/rucio@rbac`, which adds `rucio role ...`) for CVMFS.
The tarball also contains the configuration of the `rbac-test` instance, so it is ready for the Rucio tutorial in SWAN.

It reuses `../rucio/make_tarball.sh`. The only differences are:

- the client is a wheel built from the fork (`RUCIO_CLIENTS_SPEC`);
- the files in `extra/` are added to the tarball root (`EXTRA_FILES_DIR`), plus:
  - `etc/certificates/`: one hashed CA directory (Mozilla roots, CERN Root CA 2, CERN Grid CA). The Rucio servers use a public CA and EOS uses the CERN Grid CA. `X509_CERT_DIR` has priority over `[client] ca_cert`, so one directory must trust both.
  - `FORK_COMMIT`: the fork repository and commit that was built.

The version label is `<fork version>-rbac`, for example `41.1.1-rbac`.

## Build

Same prerequisites as `../rucio/README.md`.

```bash
./make_tarball.sh                 # builds hdemule/rucio@rbac
FORK_REF=<branch|tag> ./make_tarball.sh
```

The output is `rucio-clients-<version>-rbac.tar.gz` in this directory.

## Deploy to CVMFS

There is no CI workflow for this stack yet: the build uses third-party code (the fork), so it is built by hand.
Copy `rucio-clients-41.1.1-rbac.tar.gz` to the CVMFS publisher and extract it as the generic updater does
(`../rucio/utils/rucio-cvmfs-updater.sh`, target `rucio/41.1.1-rbac`):

```bash
cvmfs_server transaction sw.escape.eu
mkdir -p /cvmfs/sw.escape.eu/rucio/41.1.1-rbac
tar -xzf rucio-clients-41.1.1-rbac.tar.gz -C /cvmfs/sw.escape.eu/rucio/41.1.1-rbac
chmod -R a+rX /cvmfs/sw.escape.eu/rucio/41.1.1-rbac
cvmfs_server publish sw.escape.eu
```

## Usage

```bash
source /cvmfs/sw.escape.eu/rucio/41.1.1-rbac/setup-tutorial.sh <rucio account>
rucio whoami
```
