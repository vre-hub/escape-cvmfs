## ATLAS OpenMagic MCP Server

CVMFS packaging for [atlasopenmagic-mcp](https://github.com/atlas-outreach-data-tools/atlasopenmagic-mcp) — an MCP server exposing ATLAS Open Data metadata and file retrieval.

### CVMFS layout

MCP servers are grouped under a shared `mcp/` namespace so future ones land as
siblings rather than cluttering the top level.

```
/cvmfs/sw.escape.eu/
  mcp/atlasopenmagic-mcp/
    <version>/
      bin/
        atlasopenmagic-mcp   # wrapper script
        setup.sh             # user sources this
      venv/                  # self-contained Python virtualenv
      VERSION
    latest -> <version>/     # symlink
  atlasopenmagic-mcp -> mcp/atlasopenmagic-mcp   # back-compat symlink
```

The top-level `atlasopenmagic-mcp` path is kept as a symlink to
`mcp/atlasopenmagic-mcp` so that old references (user shell rc files, stale
opencode configs, docs pointing at the old path) keep resolving. The updater
script performs this migration automatically the first time it runs against a
publisher that still has the legacy layout.

### Publishing a new version

```bash
# From a GitHub Actions artifact (built by build_atlasopenmagic_mcp_tarball):
./utils/atlasopenmagic-mcp-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]

# Overwrite an existing published version:
./utils/atlasopenmagic-mcp-cvmfs-updater.sh -f <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
```

The script:
1. Downloads the artifact tarball, extracts it to a staging dir.
2. Opens a CVMFS transaction.
3. On first run after this change: moves the legacy `atlasopenmagic-mcp/` top-level directory to `mcp/atlasopenmagic-mcp/`, replaces the old location with a symlink.
4. Deploys the new version to `mcp/atlasopenmagic-mcp/<version>/` and updates `latest`.
5. Publishes and closes the transaction.

### Using with lumi

```bash
# Source both tools (canonical new path):
source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh
source /cvmfs/sw.escape.eu/mcp/atlasopenmagic-mcp/latest/bin/setup.sh

# The MCP server is configured in opencode.json:
# {
#   "mcp": {
#     "atlas-opendata": {
#       "type": "local",
#       "command": ["atlasopenmagic-mcp", "serve"]
#     }
#   }
# }

lumi
> @physics find ttbar MC23 samples with at least 10M events
```

The legacy top-level path still works if you already have it in scripts:

```bash
source /cvmfs/sw.escape.eu/atlasopenmagic-mcp/latest/bin/setup.sh   # resolves via symlink
```

but prefer the `mcp/`-prefixed path in new code — the symlink is kept for
grace-period compatibility and may be removed in a future cleanup.
