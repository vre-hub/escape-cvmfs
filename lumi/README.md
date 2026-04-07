## Lumi

CVMFS packaging for [lumi](https://github.com/Soap2G/opencode) — CERN's AI coding assistant built on OpenCode.

### Repository layout

```
lumi/
  config/                  # Shared config — deployed to /cvmfs/sw.escape.eu/etc/lumi/
    opencode.json          # Provider, model, MCP, permission config
    AGENTS.md              # System instructions for lumi agents
  utils/
    lumi-cvmfs-updater.sh  # Deployment script
```

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
        lumi               # symlink -> opencode
        setup.sh           # user sources this
      VERSION
    latest -> <version>/   # symlink
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
```

### User setup

```bash
source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh
lumi
```

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
