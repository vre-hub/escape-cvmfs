# rucio-clients (RBAC fork) for CVMFS

A CVMFS copy of the container image `hdemule/rucio-clients-rbac:<sha12>`. It is made for the Rucio tutorial in SWAN.
The image tag is the first 12 characters of the commit of `hdemule/rucio@rbac` that the image was built from.

The default build copies `hdemule/rucio-clients-rbac:7273054bfdc4`.

## What the image has, and where each part comes from here

| Image (`rbac.Dockerfile`) | CVMFS tarball |
|---|---|
| Base `rucio/rucio-clients:release-41.1.1` (Python 3.9, dependency versions) | Dependency versions pinned in `constraints-image.txt` (read from the image layers). Python is the one of the host (SWAN), through `RUCIO_PYTHONBIN`. The tarball has `site-packages` for **Python 3.11, 3.12 and 3.13** (3.11.9, 3.12.2, 3.13.11 in the build). |
| Client wheel of the fork, built from one commit with `tools/build_sdist_wheel.sh clients` and this `vcsversion.py`: `VERSION='41.0.0rc1+rbac.<sha12>'`, `BRANCH_NICK='rbac'` | Same commit, same version file, same command. `make_tarball.sh` checks that the wheel content is **identical** to the wheel in the image (hash of every file, except `dist-info/WHEEL`: it records the `setuptools` version of the build, which depends on the Python version of the build). |
| `/opt/rucio/etc/rucio.cfg` | `etc/rucio.cfg`. One change: `ca_cert = $RUCIO_HOME/etc/tls-ca-bundle.pem` (the client expands the variable), so the file does not depend on the folder name. `RUCIO_CONFIG` points to it. |
| `/certs/tls-ca-bundle.pem` (152 certificates, with Sectigo and the CERN CAs) | `etc/tls-ca-bundle.pem`, the same file. `etc/certificates/` is a hashed CA directory made from it, for `X509_CERT_DIR` (EOS downloads with `gfal2`, and the Rucio API). |
| `/usr/local/bin/set-username` (edits `rucio.cfg`, removes the token) | A shell function `set-username` in `setup-tutorial.sh`. The config on CVMFS is read-only, so it sets `RUCIO_ACCOUNT` and removes the token. |
| `git clone … /opt/rucio-tutorial` | Not included. Students clone the tutorial repository. |
| `gfal2` (RPM packages in the image) | The one of the host. SWAN has it in its LCG stack (not tested). |

## Build in CI (GitHub Actions)

The workflow `.github/workflows/build_rucio-rbac_tarball.yaml` builds the tarball and uploads it as the artifact
`rucio-clients-rbac` (the `.tar.gz` and its `.sha256`).

- It runs on every push to `main` that changes `rucio-rbac/**`, `rucio/make_tarball.sh` or `rucio/common/**`.
- Manual run: *Actions* → *Build Rucio RBAC Clients Tarball* → *Run workflow*. The optional input `fork_sha` is a full
  commit (40 characters) of `hdemule/rucio`. Empty means the commit in `make_tarball.sh`.
- The commit is always pinned. A branch name or a tag is refused. For the default commit, the build stops if the
  wheel is not identical to the wheel in the image.

## Build by hand

Needs Linux or macOS, `pyenv` with Python 3.11.9, 3.12.2 and 3.13.11 (the build installs them if they are missing; an old `pyenv` may not know 3.13.11: run `pyenv update`), `pyenv-virtualenv`, `git`, `openssl`, `rsync`, `unzip`.
Same prerequisites as `../rucio/README.md`.

```bash
deactivate                  # no virtualenv may be active (the script checks this)
./make_tarball.sh           # copy of hdemule/rucio-clients-rbac:7273054bfdc4
```

Other commit: `FORK_SHA=<40 characters> ./make_tarball.sh` (the check against the image wheel is skipped).
Other Python versions: `RUCIO_PYTHON_VERSIONS="3.11.9 3.12.2 3.13.11" ./make_tarball.sh` (a space-separated list).
Output: `rucio-clients-41.1.1-rbac-<sha12>.tar.gz` and `.sha256` in this folder.

To get the dependency versions of another image, read the `site-packages` folder in its layers and update `constraints-image.txt`.

## Deploy to CVMFS

On the CVMFS publisher machine, with the updater script. Either from the artifact:

```bash
rucio-rbac/utils/rucio-rbac-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID> [LABEL]      # add -f to replace an existing folder
```

(`ARTIFACT_ID` is in the URL of the artifact on the workflow run page.) Or with a tarball that you copied to the machine
(for example the file from the artifact zip, with `scp`):

```bash
rucio-rbac/utils/rucio-rbac-cvmfs-updater.sh -t rucio-clients-41.1.1-rbac-7273054bfdc4.tar.gz
```

`utils/rucio-rbac-cvmfs-updater.sh` checks the `.sha256` file if it is next to the tarball, extracts into
`/cvmfs/sw.escape.eu/rucio/<LABEL>`, sets `a+rX`, and publishes. If a step fails, it aborts the CVMFS transaction.
The same steps by hand:

```bash
cvmfs_server transaction sw.escape.eu
mkdir -p /cvmfs/sw.escape.eu/rucio/41.1.1-rbac-7273054bfdc4
tar -xzf rucio-clients-41.1.1-rbac-7273054bfdc4.tar.gz -C /cvmfs/sw.escape.eu/rucio/41.1.1-rbac-7273054bfdc4
chmod -R a+rX /cvmfs/sw.escape.eu/rucio/41.1.1-rbac-7273054bfdc4
cvmfs_server publish sw.escape.eu
```

## Use

```bash
source /cvmfs/sw.escape.eu/rucio/41.1.1-rbac-7273054bfdc4/setup-tutorial.sh [<rucio account>]
rucio whoami          # shows the OIDC login link
set-username <acc>    # choose another account (or run without argument to remove it)
```

## Notes

- The OIDC token lasts about one hour. After that, the next command starts a new login.
- The fork moves on. On 6 October the `rbac` branch was 8 commits ahead of this image, including changes to the server-side policy (built-in roles, and the `admin` account attribute replaced by a role check). The tutorial admin scripts use the `admin` attribute. Update both together.
