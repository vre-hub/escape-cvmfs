## Pi

CVMFS packaging for the [Pi coding agent](https://github.com/earendil-works/pi),
started through `lumi --pi` (see [`../lumi/README.md`](../lumi/README.md)).
The Lumi config for Pi is generated in the
[open-data-assistant-config](https://github.com/Soap2G/lumi-assistant) repo
(`script/build_pi_package.py`) and is not part of this tree.

### Layout

```
pi/
  app/package.json        # pins @earendil-works/pi-coding-agent
  app/package-lock.json   # pinned dependency tree (reviewed diff on upgrade)
  bin/pi                  # launcher template
  make_tarball.sh         # builds pi-<version>.tar.gz (run in almalinux:9)
  utils/pi-cvmfs-updater.sh
```

### CVMFS layout

```
/cvmfs/sw.escape.eu/pi/
  <pi-version>/
    node/bin/node         # official Node.js linux-x64 (binary + LICENSE only)
    app/node_modules/...  # npm ci --ignore-scripts from the lockfile
    bin/pi                # runs ../node/bin/node explicitly, Node is not put on PATH
    VERSION
    NODE_VERSION
  latest -> <pi-version>/
```

### Publishing

```bash
# From a GitHub artifact (workflow "Build Pi Tarball"):
./utils/pi-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]

# From a local tarball:
./utils/pi-cvmfs-updater.sh --tarball pi-<version>.tar.gz

# Overwrite an existing version:
./utils/pi-cvmfs-updater.sh -f --tarball pi-<version>.tar.gz
```

### Bump Pi

1. Edit the version in `app/package.json` (exact pin, no range).
2. `cd app && npm install --package-lock-only --ignore-scripts`.
3. Commit both files. Review the `package-lock.json` diff.
4. Run the workflow, publish, then run the `lumi --pi` acceptance list.

### Bump Node

Change `NODE_VERSION` and `NODE_SHA256` in
`.github/workflows/build_pi_tarball.yaml`. The hash is in
`https://nodejs.org/dist/v<NODE_VERSION>/SHASUMS256.txt` (file
`node-v<NODE_VERSION>-linux-x64.tar.xz`). Pi needs Node 22.19 or later.
