#!/bin/bash
#
# root-mcp-cvmfs-updater.sh — Deploy root-mcp (+ root-cli) to CVMFS
#
# root-mcp is a PyPI package (https://pypi.org/project/root-mcp/) that ships
# two console scripts:
#   - root-mcp  : MCP server (stdio JSON-RPC)
#   - root-cli  : human-readable CLI wrapper over the same backend
# Both are exposed from the CVMFS deployment.
#
# Usage:
#   From PyPI (default):
#     ./root-mcp-cvmfs-updater.sh [-f|--force] [--xrootd] <VERSION>
#
#   From local repo (checkout):
#     ROOT_MCP_REPO=/path/to/root-mcp \
#       ./root-mcp-cvmfs-updater.sh [-f] [--xrootd] [VERSION]
#
#   From GitHub artifact (pre-built tarball from a CI workflow):
#     ./root-mcp-cvmfs-updater.sh [-f] --artifact <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
#
# Options:
#   -f, --force    Replace existing version if it exists
#   --xrootd       Include the optional [xrootd] extra (remote file access)
#
# The runtime wrapper sources an LCG view (defaults to
# LCG_107/x86_64-el9-gcc13-opt) before exec'ing Python. This pulls in PyROOT,
# uproot, numpy, matplotlib, scipy, XRootD, etc. from CVMFS — so the optional
# native-ROOT features (run_root_code / run_rdataframe / run_root_macro) work
# out of the box. Override the view with LCG_VIEW; override the build-stage
# Python with BUILD_PYTHON.
#
# Mirrors the pattern used by mcp/atlasopenmagic-mcp/ in this repo.
#

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
MOUNTPOINT="/cvmfs/sw.escape.eu"
PACKAGE="root-mcp"
# Namespace: MCP servers live under /cvmfs/sw.escape.eu/mcp/<name>/<version>/
NAMESPACE="mcp"
LCG_VIEW_DEFAULT="/cvmfs/sft.cern.ch/lcg/views/LCG_107/x86_64-el9-gcc13-opt"
LCG_VIEW="${LCG_VIEW:-$LCG_VIEW_DEFAULT}"
LCG_PYTHON="${LCG_VIEW}/bin/python3"
BUILD_PYTHON="${BUILD_PYTHON:-$LCG_PYTHON}"

# Fallback: if LCG Python is not mounted locally, try system python3 for the
# build stage only (the deployed wrapper still sources the LCG view at run
# time, so PyROOT etc. come from CVMFS regardless of what built the venv).
if [ ! -x "$BUILD_PYTHON" ]; then
  if command -v python3 >/dev/null 2>&1; then
    echo "NOTE: LCG Python not available at ${BUILD_PYTHON}"
    echo "      falling back to $(command -v python3) for the build stage only."
    BUILD_PYTHON="$(command -v python3)"
  else
    echo "ERROR: no usable Python interpreter found (tried ${BUILD_PYTHON} and python3)"
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
FORCE=false
XROOTD=false
MODE="pypi"
TOKEN=""
ARTIFACT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE=true
      shift
      ;;
    --xrootd)
      XROOTD=true
      shift
      ;;
    --artifact)
      MODE="artifact"
      shift
      TOKEN="${1:-}"
      shift || true
      ARTIFACT_ID="${1:-}"
      shift || true
      ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    -*)
      echo "ERROR: unknown option: $1"
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

VERSION="${1:-}"

# If ROOT_MCP_REPO is set, we're in local-repo mode
if [[ -n "${ROOT_MCP_REPO:-}" ]]; then
  if [[ "$MODE" == "artifact" ]]; then
    echo "ERROR: cannot combine --artifact with ROOT_MCP_REPO"
    exit 1
  fi
  MODE="local"
fi

# ---------------------------------------------------------------------------
# Prepare staging dir (holds the pre-publish layout)
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

STAGING="${TMPDIR}/staging"
SITE_PACKAGES="${STAGING}/lib/python3.11/site-packages"
mkdir -p "${STAGING}/bin" "${SITE_PACKAGES}"

# ---------------------------------------------------------------------------
# Fetch / build the package
# ---------------------------------------------------------------------------
# Full install: all of root-mcp's deps land in site-packages. At runtime the
# LCG view is sourced first, so LCG's numpy/pandas/uproot/PyROOT etc. win on
# PYTHONPATH (ABI-safe). Our site-packages are appended, providing root_mcp,
# root_cli, and any MCP-layer deps (mcp, pydantic-settings, …) that LCG
# doesn't ship. Redundant scientific deps in site-packages are harmless —
# they're just shadowed by LCG and never loaded.

EXTRA=""
if $XROOTD; then
  EXTRA="[xrootd]"
fi

pip_install_target () {
  local spec="$1"
  local label="$2"
  echo "Installing ${spec} (${label}) into staging using ${BUILD_PYTHON}..."
  "$BUILD_PYTHON" -m pip install \
    --target "$SITE_PACKAGES" \
    --upgrade \
    "$spec"
}

case "$MODE" in
  pypi)
    if [[ -z "$VERSION" ]]; then
      echo "ERROR: VERSION required in PyPI mode."
      echo "Usage: $0 [-f] [--xrootd] <VERSION>"
      exit 1
    fi
    pip_install_target "${PACKAGE}${EXTRA}==${VERSION}" "PyPI"
    ;;

  local)
    if [[ ! -d "$ROOT_MCP_REPO" ]]; then
      echo "ERROR: ROOT_MCP_REPO=${ROOT_MCP_REPO} is not a directory"
      exit 1
    fi
    if [[ -z "$VERSION" ]]; then
      VERSION=$(grep -E '^\s*version\s*=' "${ROOT_MCP_REPO}/pyproject.toml" \
                  | head -1 \
                  | sed -E 's/.*"([^"]+)".*/\1/')
      if [[ -z "$VERSION" ]]; then
        echo "ERROR: could not auto-detect version from ${ROOT_MCP_REPO}/pyproject.toml"
        exit 1
      fi
      echo "Auto-detected version: ${VERSION}"
    fi
    pip_install_target "${ROOT_MCP_REPO}${EXTRA}" "local repo"
    ;;

  artifact)
    if [[ -z "$TOKEN" || -z "$ARTIFACT_ID" ]]; then
      echo "ERROR: --artifact requires <GITHUB_TOKEN> <ARTIFACT_ID>"
      exit 1
    fi
    REPO_URL="https://api.github.com/repos/vre-hub/escape-cvmfs/actions/artifacts/${ARTIFACT_ID}/zip"
    echo "Downloading GitHub artifact ${ARTIFACT_ID}..."
    curl -Ls \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "$REPO_URL" -o "${TMPDIR}/artifact.zip"
    ( cd "$TMPDIR" && unzip -q artifact.zip )

    TARBALL=$(ls "${TMPDIR}"/root-mcp-*.tar.gz 2>/dev/null | head -1)
    if [[ -z "$TARBALL" ]]; then
      echo "ERROR: no root-mcp-*.tar.gz found in artifact"
      ls -la "$TMPDIR"
      exit 1
    fi
    if [[ -z "$VERSION" ]]; then
      VERSION=$(basename "$TARBALL" | sed 's/^root-mcp-//; s/\.tar\.gz$//')
      echo "Auto-detected version from tarball: ${VERSION}"
    fi
    # Artifact tarballs are expected to contain the same layout we build
    # locally: bin/ + lib/python3.11/site-packages/ + VERSION
    rm -rf "$STAGING"
    mkdir -p "$STAGING"
    tar -xzf "$TARBALL" -C "$STAGING"
    ;;
esac

# ---------------------------------------------------------------------------
# Write wrapper scripts
# ---------------------------------------------------------------------------
# Only (re)generate wrappers for pypi/local modes. Artifact mode assumes the
# tarball already contains them.
if [[ "$MODE" != "artifact" ]]; then
  echo "${VERSION}" > "${STAGING}/VERSION"

  write_wrapper () {
    local name="$1"
    local entry="$2"  # e.g. root_mcp.server:main
    local module="${entry%:*}"
    local func="${entry#*:}"
    local path="${STAGING}/bin/${name}"
    cat > "$path" <<WRAPPER
#!/usr/bin/env bash
# ${name} — CVMFS wrapper (auto-generated by root-mcp-cvmfs-updater.sh)
#
# Sources the LCG view first so LCG's numpy/ROOT/uproot/etc. come first on
# PYTHONPATH (ABI-safe for PyROOT). Our site-packages are appended, adding
# root_mcp, root_cli, and any MCP-layer deps LCG doesn't ship.
set -e

_dir="\$(cd "\$(dirname "\$0")/.." && pwd)"
_view="${LCG_VIEW}"
_view_setup="\${_view}/setup.sh"

if [ ! -r "\$_view_setup" ]; then
  echo "ERROR: LCG view not found at \$_view" >&2
  echo "       Make sure /cvmfs/sft.cern.ch is mounted." >&2
  exit 1
fi

# shellcheck disable=SC1090
. "\$_view_setup"

# Append (not prepend) so LCG's scientific stack takes precedence
export PYTHONPATH="\${PYTHONPATH:+\${PYTHONPATH}:}\${_dir}/lib/python3.11/site-packages"

exec python3 -c "import sys; from ${module} import ${func}; sys.exit(${func}() or 0)" "\$@"
WRAPPER
    chmod +x "$path"
  }

  write_wrapper root-mcp "root_mcp.server:main"
  write_wrapper root-cli "root_cli.main:main"

  # setup.sh
  cat > "${STAGING}/bin/setup.sh" <<'SETUP'
#!/usr/bin/env bash
# root-mcp CVMFS setup — source to put root-mcp and root-cli on $PATH.
# Usage: source /cvmfs/sw.escape.eu/mcp/root-mcp/latest/bin/setup.sh

_rootmcp_dir="/cvmfs/sw.escape.eu/mcp/root-mcp/latest/bin"

case ":${PATH}:" in
  *":${_rootmcp_dir}:"*) ;;
  *) export PATH="${_rootmcp_dir}:${PATH}" ;;
esac

export ROOT_MCP_VERSION="$(cat "${_rootmcp_dir}/../VERSION" 2>/dev/null || echo unknown)"

echo "root-mcp v${ROOT_MCP_VERSION} ready  (root-mcp, root-cli on PATH)"

unset _rootmcp_dir
SETUP
  chmod +x "${STAGING}/bin/setup.sh"

  # Smoke test: verify the installed package imports *through the LCG view*
  # (so any PyROOT/uproot binding mismatch surfaces at publish time, not at
  # user runtime). Non-fatal if the view isn't mounted on the publisher.
  if [ -r "${LCG_VIEW}/setup.sh" ]; then
    echo "Smoke test: importing root_mcp + ROOT via ${LCG_VIEW}..."
    env -i HOME="$HOME" PATH="/usr/bin:/bin" bash -c "
      set -e
      . '${LCG_VIEW}/setup.sh'
      export PYTHONPATH=\"\${PYTHONPATH:+\${PYTHONPATH}:}${SITE_PACKAGES}\"
      python3 -c 'import root_mcp, root_cli; print(\"root-mcp OK:\", getattr(root_mcp, \"__version__\", \"?\"))'
      python3 -c 'import ROOT; print(\"PyROOT OK:\", ROOT.gROOT.GetVersion())'
    " || { echo "ERROR: import smoke test failed."; exit 1; }
  else
    echo "Skipping smoke test (LCG view not mounted at ${LCG_VIEW})."
  fi
fi

# ---------------------------------------------------------------------------
# Publish to CVMFS
# ---------------------------------------------------------------------------
TARGET_DIR="${NAMESPACE}/${PACKAGE}/${VERSION}"
LATEST_LINK="${NAMESPACE}/${PACKAGE}/latest"

echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu

cd "$MOUNTPOINT"

# Ensure namespace dir exists (first publish into mcp/ creates it)
mkdir -p "${NAMESPACE}/${PACKAGE}"

if [ -d "$TARGET_DIR" ]; then
  if [ "$FORCE" = true ]; then
    echo "Directory ${TARGET_DIR} exists. --force set — removing..."
    rm -rf "$TARGET_DIR"
  else
    echo "Directory ${TARGET_DIR} already exists. Use -f to overwrite."
    cvmfs_server abort sw.escape.eu
    exit 1
  fi
fi

echo "Deploying to ${TARGET_DIR}..."
mkdir -p "$TARGET_DIR"
cp -a "${STAGING}/"* "${TARGET_DIR}/"

ln -sfn "${VERSION}" "${LATEST_LINK}"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo ""
echo "Done. Published ${PACKAGE} v${VERSION}"
echo ""
echo "CVMFS layout:"
echo "  ${MOUNTPOINT}/${TARGET_DIR}/bin/root-mcp           (MCP server wrapper)"
echo "  ${MOUNTPOINT}/${TARGET_DIR}/bin/root-cli           (CLI wrapper)"
echo "  ${MOUNTPOINT}/${TARGET_DIR}/bin/setup.sh           (source this)"
echo "  ${MOUNTPOINT}/${TARGET_DIR}/lib/python3.11/site-packages/"
echo "  ${MOUNTPOINT}/${LATEST_LINK} -> ${VERSION}"
echo ""
echo "Users can now run:"
echo "  source ${MOUNTPOINT}/${LATEST_LINK}/bin/setup.sh"
echo ""
echo "opencode.json integration (MCP server):"
echo '  "mcp": {'
echo '    "root-mcp": {'
echo '      "type": "local",'
echo "      \"command\": [\"${MOUNTPOINT}/${LATEST_LINK}/bin/root-mcp\", \"--data-path\", \"/your/data\"]"
echo '    }'
echo '  }'
echo ""
echo "Or use root-cli directly via opencode's Bash tool (no mcp block needed)."
echo ""
echo "MCP servers now live under ${MOUNTPOINT}/${NAMESPACE}/. Lumi and other"
echo "consumers should reference the full path above."
