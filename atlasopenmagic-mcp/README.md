## ATLAS OpenMagic MCP Server

CVMFS packaging for [atlasopenmagic-mcp](https://github.com/atlas-outreach-data-tools/atlasopenmagic-mcp) — an MCP server exposing ATLAS Open Data metadata and file retrieval.

### CVMFS layout

```
/cvmfs/sw.escape.eu/atlasopenmagic-mcp/
  <version>/
    bin/
      atlasopenmagic-mcp   # wrapper script
      setup.sh             # user sources this
    venv/                  # self-contained Python virtualenv
    VERSION
  latest -> <version>/     # symlink
```

### Publishing a new version

```bash
# From PyPI:
./utils/atlasopenmagic-mcp-cvmfs-updater.sh 0.1.0

# From local repo:
ATLASOPENMAGIC_MCP_REPO=/path/to/atlasopenmagic-mcp \
  ./utils/atlasopenmagic-mcp-cvmfs-updater.sh 0.1.0

# Overwrite existing:
./utils/atlasopenmagic-mcp-cvmfs-updater.sh -f 0.1.0
```

### Using with lumi

```bash
# Source both tools
source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh
source /cvmfs/sw.escape.eu/atlasopenmagic-mcp/latest/bin/setup.sh

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
