## ROOT MCP Server

CVMFS packaging for [root-mcp](https://github.com/MohamedElashri/root-mcp) — an
MCP server and CLI for CERN ROOT files. The PyPI package ships two console
scripts; both are exposed from CVMFS:

- `root-mcp` — MCP server (JSON-RPC over stdio) for MCP-aware clients.
- `root-cli` — human-readable CLI over the same backend, invokable from any
  shell (useful with lumi's Bash tool without registering an MCP server).

### CVMFS layout

MCP servers are grouped under a shared `mcp/` namespace so future ones land as
siblings rather than cluttering the top level.

```
/cvmfs/sw.escape.eu/mcp/root-mcp/
  <version>/
    bin/
      root-mcp          # wrapper — sources LCG view, execs python3
      root-cli          # wrapper — sources LCG view, execs python3
      setup.sh          # user sources this
    lib/python3.11/site-packages/   # root-mcp + MCP-layer bridge deps only
    VERSION
  latest -> <version>/
```

The wrappers source `/cvmfs/sft.cern.ch/lcg/views/LCG_107/x86_64-el9-gcc13-opt/setup.sh`
before exec'ing Python. Scientific deps (`numpy`, `pandas`, `uproot`, `awkward`,
`scipy`, `matplotlib`, `pyarrow`, `XRootD`, **PyROOT**) come from the LCG view;
the CVMFS site-packages only holds `root-mcp` itself plus the MCP-layer
bridge deps (`mcp`, `pydantic`, `pydantic-settings`, `aiofiles`, `xxhash`,
`click`) that LCG 107 doesn't ship.

This layout is deliberate: re-pip-installing `numpy` would shadow the LCG
view's numpy and risk breaking `import ROOT` via ABI mismatch.

### Publishing a new version

```bash
# From PyPI:
./utils/root-mcp-cvmfs-updater.sh 0.1.0

# With the optional [xrootd] extra (remote file access via XRootD):
./utils/root-mcp-cvmfs-updater.sh --xrootd 0.1.0

# From a local checkout:
ROOT_MCP_REPO=/path/to/root-mcp \
  ./utils/root-mcp-cvmfs-updater.sh 0.1.0

# From a GitHub Actions artifact (pre-built tarball):
./utils/root-mcp-cvmfs-updater.sh --artifact <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]

# Overwrite an existing published version:
./utils/root-mcp-cvmfs-updater.sh -f 0.1.0
```

The script defaults to the LCG view `LCG_107/x86_64-el9-gcc13-opt` for both
the build stage and the runtime wrapper. Override with `LCG_VIEW` (both
stages) or `BUILD_PYTHON` (build stage only) if you need a different
release/platform. The build stage falls back to system `python3` when LCG is
not mounted on the publisher host; the runtime wrapper always sources the
LCG view.

Before publishing, the script runs a smoke test that imports `root_mcp`,
`root_cli`, and `ROOT` through the LCG view — so any ABI mismatch surfaces at
publish time rather than at user runtime. The smoke test is skipped (with a
warning) when the view isn't mounted on the publisher host.

### Using with lumi

```bash
source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh
source /cvmfs/sw.escape.eu/mcp/root-mcp/latest/bin/setup.sh
lumi
```

With the setup script sourced, `root-cli` is on `$PATH` and lumi can call it
directly through its Bash tool — no `mcp` block required, no per-tool context
overhead. Example prompt:

```
> Plot the muon pT distribution from /data/sample.root
```

#### Alternative: register as an MCP server

If you prefer the full MCP interface (structured tool schemas), add this to
`opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "root-mcp": {
      "type": "local",
      "command": [
        "/cvmfs/sw.escape.eu/mcp/root-mcp/latest/bin/root-mcp",
        "--data-path", "/your/data"
      ]
    }
  }
}
```

Note that this registers ~17–20 tools which add to context on every turn; the
project author recommends the CLI interface for LLM use.

### Native ROOT / PyROOT

Native ROOT tools (`run_root_code`, `run_rdataframe`, `run_root_macro`) *are*
supported, because the wrapper sources the LCG view which includes PyROOT.
To enable them, start the server with:

```bash
root-mcp --data-path /your/data --enable-root
```

You can sanity-check at runtime via the `get_server_info` MCP tool — it
reports `root_native_available: true` and the detected ROOT version.

### Caveats

- **Platform lock-in**: the wrapper hard-codes the `x86_64-el9-gcc13-opt` LCG
  view. Hosts running a different OS/arch (macOS, ARM, etc.) need a rebuild
  with the matching `LCG_VIEW`. This mirrors the lumi setup.
- **Bridge-deps drift**: the script pip-installs a small explicit list of
  MCP-layer deps (`mcp`, `pydantic`, `pydantic-settings`, `aiofiles`,
  `xxhash`, `click`) because LCG 107 doesn't ship them. If root-mcp adds new
  non-scientific runtime deps upstream, update `BRIDGE_DEPS` in the updater
  script accordingly.
