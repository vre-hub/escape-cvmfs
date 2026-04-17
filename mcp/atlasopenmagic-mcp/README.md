# atlasopenmagic-mcp on CVMFS

CVMFS packaging for
[atlasopenmagic-mcp](https://github.com/atlas-outreach-data-tools/atlasopenmagic-mcp) —
an MCP server exposing ATLAS Open Data metadata and file retrieval.

## Layout

```
/cvmfs/sw.escape.eu/mcp/atlasopenmagic-mcp/
├── <version>/
│   ├── VERSION
│   ├── bin/{atlasopenmagic-mcp, setup.sh}
│   └── lib/python3.11/site-packages/...
└── latest -> <version>
```

## Flow

1. **CI** — push to `main` under `mcp/atlasopenmagic-mcp/**`, or trigger
   `Build atlasopenmagic-mcp Tarball` manually with a PyPI version. Download
   the `atlasopenmagic-mcp` artifact.
2. **Deploy** — on the CVMFS publisher:
   ```
   scp atlasopenmagic-mcp-<version>.tar.gz publisher:
   ssh publisher
   ./script/deploy-mcp.sh atlasopenmagic-mcp <version> atlasopenmagic-mcp-<version>.tar.gz
   ```

## Use from lumi

```bash
source /cvmfs/sw.escape.eu/mcp/atlasopenmagic-mcp/latest/bin/setup.sh
```

Then in `opencode.json` / `lumi.json`:
```json
{
  "mcp": {
    "atlas-opendata": {
      "type": "local",
      "command": ["atlasopenmagic-mcp", "serve"]
    }
  }
}
```

The wrapper execs LCG 107's `python3` with our site-packages on
`PYTHONPATH`.
