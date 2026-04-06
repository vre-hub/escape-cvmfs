## Lumi

CVMFS packaging for [lumi](https://github.com/gguerrie/opencode) — CERN's AI coding assistant built on OpenCode.

### CVMFS layout

```
/cvmfs/sw.escape.eu/lumi/
  <version>/
    bin/
      opencode       # compiled binary
      lumi           # symlink -> opencode
      setup.sh       # user sources this
    VERSION
  latest -> <version>/   # symlink
```

### Publishing a new version

```bash
# From source (set OPENCODE_REPO to your local clone):
OPENCODE_REPO=/path/to/opencode ./utils/lumi-cvmfs-updater.sh 1.3.15

# From GitHub release:
./utils/lumi-cvmfs-updater.sh 1.3.15

# Overwrite existing version:
./utils/lumi-cvmfs-updater.sh -f 1.3.15
```

### User setup

```bash
source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh
lumi
```
