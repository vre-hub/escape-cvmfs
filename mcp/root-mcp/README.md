# root-mcp on CVMFS

[`root-mcp`](https://github.com/MohamedElashri/root-mcp) packaged for
`/cvmfs/sw.escape.eu/mcp/root-mcp/`. The wrappers source the LCG 107 view
(`x86_64-el9-gcc13-opt`) so native PyROOT works without ABI surprises.

Two entry points ship from the tarball:
- `root-mcp` — MCP server (JSON-RPC over stdio)
- `root-cli` — same backend, human/CLI-friendly; callable from lumi's Bash tool

## Layout

```
/cvmfs/sw.escape.eu/mcp/root-mcp/
├── <version>/
│   ├── VERSION
│   ├── bin/{root-mcp, root-cli, setup.sh}
│   └── lib/python3.11/site-packages/...
└── latest -> <version>
```

## Flow

1. **CI** — push to `main` under `mcp/root-mcp/**`, or trigger
   `Build root-mcp Tarball` manually with a PyPI version. Download the
   `root-mcp` artifact.
2. **Deploy** — on the CVMFS publisher:
   ```
   scp root-mcp-<version>.tar.gz publisher:
   ssh publisher
   ./script/deploy-mcp.sh root-mcp <version> root-mcp-<version>.tar.gz
   ```
   `deploy-mcp.sh` opens a CVMFS transaction, extracts into
   `mcp/root-mcp/<version>/`, flips `latest`, and publishes.

## Use from lumi

```bash
source /cvmfs/sw.escape.eu/mcp/root-mcp/latest/bin/setup.sh
```

`root-mcp` and `root-cli` end up on `$PATH`. To register the MCP server in
`opencode.json` / `lumi.json`:

```json
{
  "mcp": {
    "root-mcp": {
      "type": "local",
      "command": ["root-mcp", "--data-path", "/your/data"]
    }
  }
}
```

For native ROOT tools (`run_root_code`, `run_rdataframe`, `run_root_macro`),
add `--enable-root`.

## Notes

- Platform lock-in: wrappers hard-code `LCG_107/x86_64-el9-gcc13-opt`. Other
  OS/arch needs a rebuild with a different `LCG_VIEW` path in the wrappers.
- The CI does a full `pip install` into the tarball's site-packages. At
  runtime the LCG view is sourced first, so LCG's numpy/ROOT/uproot win on
  `PYTHONPATH` (ABI-safe for PyROOT) and our site-packages are appended.
