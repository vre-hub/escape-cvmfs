## Lumi

CVMFS packaging for [lumi](https://github.com/Soap2G/opencode) — CERN's AI coding assistant built on OpenCode.

### Repository layout

```
lumi/
  bin/
    lumi                   # entry point: opencode, or Pi with --pi
    lumi-pi                # starts Pi with the Lumi config (experimental)
  config/                  # LEGACY (old root-help/physics content), do not edit.
                           # The live config comes from atom-assistant
                           # (open-data-assistant-config repo).
  utils/
    lumi-cvmfs-updater.sh  # Deployment script
```

The Pi runtime itself (Node + Pi) lives in [`../pi/`](../pi/README.md).

### CVMFS layout

```
/cvmfs/sw.escape.eu/
  etc/lumi/                # Shared config (version-independent)
    opencode.json
    AGENTS.md
  lumi/
    <version>/
      bin/
        opencode           # compiled binary
        lumi               # script: opencode, or lumi-pi with --pi
        lumi-pi            # starts Pi with the Lumi config
        setup.sh           # user sources this
      VERSION
    latest -> <version>/   # symlink
  pi/                      # Pi runtime, own version axis (see ../pi/README.md)
    <pi-version>/
    latest -> <pi-version>/
  etc/lumi/atom-assistant/<version>/
    config/                # opencode reads this
    pi/                    # generated Pi config, read by lumi-pi
```

The config directory (`etc/lumi/`) is **version-independent** — it can be updated
without re-publishing the binary. The updater script copies `config/` from this
repo to CVMFS on each publish.

### Publishing a new version

```bash
# From source (set OPENCODE_REPO to your local clone):
OPENCODE_REPO=/path/to/opencode ./utils/lumi-cvmfs-updater.sh 1.3.15

# From GitHub artifact:
./utils/lumi-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]

# Overwrite existing version:
./utils/lumi-cvmfs-updater.sh -f 1.3.15

# Update only lumi, lumi-pi and setup.sh in an existing version (no new binary).
# Default version: the target of lumi/latest.
./utils/lumi-cvmfs-updater.sh --scripts-only [VERSION]
```

### User setup

```bash
source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh
lumi          # opencode with the Lumi config
lumi --pi     # Pi with the Lumi config (experimental)
```

`--pi` is read only as the first argument. Pi does not ask before it runs
commands, so `lumi --pi` is for a pilot group. `lumi --pi update` and
`lumi --pi install` are blocked: CVMFS manages Pi. Overrides:
`LUMI_PI_BIN`, `LUMI_ASSISTANT_ROOT`, `LUMI_PI_HOME` (agent dir, default
`~/.lumi/pi`).

### Configuration

The setup script sets `OPENCODE_CONFIG_DIR=/cvmfs/sw.escape.eu/etc/lumi`, which
tells lumi to load config, agents, and system instructions from the shared CVMFS
directory. Users can still override settings in their personal
`~/.config/opencode/opencode.json` or project-level `opencode.json`.

#### Editing the shared config

Edit the files under `config/` in this repo and re-run the updater script. The
config is deployed to CVMFS independently of the binary version.

#### LiteLLM API key

Users store their key in `~/.lumi/litellm-key` (mode `0600`):

```bash
mkdir -p ~/.lumi && chmod 700 ~/.lumi
echo "sk-your-key" > ~/.lumi/litellm-key
chmod 600 ~/.lumi/litellm-key
```

See the [auth options doc](../docs/lumi-litellm-auth-options.md) for alternatives.
