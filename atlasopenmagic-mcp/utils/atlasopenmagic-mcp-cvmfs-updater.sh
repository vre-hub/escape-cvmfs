#!/bin/bash
#
# atlasopenmagic-mcp-cvmfs-updater.sh — Package and publish the MCP server to CVMFS
#
# Usage:
#   ./atlasopenmagic-mcp-cvmfs-updater.sh [-f|--force] <VERSION>
#
# Options:
#   -f, --force    Replace existing version if it exists
#
# This script:
#   1. Creates a self-contained Python virtualenv with atlasopenmagic-mcp installed
#   2. Packages it for CVMFS with a setup.sh
#   3. Publishes to /cvmfs/sw.escape.eu/atlasopenmagic-mcp/
#
# The MCP server can then be used by lumi (or any MCP client) via:
#   source /cvmfs/sw.escape.eu/atlasopenmagic-mcp/latest/bin/setup.sh
#   atlasopenmagic-mcp serve
#

set -euo pipefail

# Parse options
FORCE=false
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE=true
      shift
      ;;
    *)
      break
      ;;
  esac
done

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Error: VERSION must be provided."
  echo "Usage: $0 [-f|--force] <VERSION>"
  echo "Example: $0 0.1.0"
  exit 1
fi

MOUNTPOINT="/cvmfs/sw.escape.eu"
TARGET_DIR="atlasopenmagic-mcp/${VERSION}"
LATEST_LINK="atlasopenmagic-mcp/latest"

# ---------------------------------------------------------------------------
# Build a self-contained virtualenv
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

VENV="${TMPDIR}/venv"
echo "Creating virtualenv..."
python3 -m venv "$VENV"
source "${VENV}/bin/activate"

echo "Installing atlasopenmagic-mcp..."
if [[ -n "${ATLASOPENMAGIC_MCP_REPO:-}" ]]; then
  # Install from local repo
  pip install --no-cache-dir "${ATLASOPENMAGIC_MCP_REPO}"
else
  # Install from PyPI (or GitHub)
  pip install --no-cache-dir "atlasopenmagic-mcp==${VERSION}"
fi

# Verify installation
atlasopenmagic-mcp --help >/dev/null 2>&1 || {
  echo "ERROR: atlasopenmagic-mcp not working after install"
  exit 1
}

deactivate

# ---------------------------------------------------------------------------
# Stage the CVMFS directory
# ---------------------------------------------------------------------------
STAGE="${TMPDIR}/stage"
mkdir -p "${STAGE}/bin"

# Copy the entire virtualenv
cp -a "${VENV}" "${STAGE}/venv"

# Write version marker
echo "${VERSION}" > "${STAGE}/VERSION"

# Write wrapper script
cat > "${STAGE}/bin/atlasopenmagic-mcp" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# Wrapper that activates the bundled venv and runs the MCP server
_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
exec "${_dir}/venv/bin/atlasopenmagic-mcp" "$@"
WRAPPER_EOF
chmod +x "${STAGE}/bin/atlasopenmagic-mcp"

# Write setup.sh
cat > "${STAGE}/bin/setup.sh" << 'SETUP_EOF'
#!/usr/bin/env bash
# atlasopenmagic-mcp setup for CVMFS
# Usage: source /cvmfs/sw.escape.eu/atlasopenmagic-mcp/latest/bin/setup.sh

_mcp_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

case ":${PATH}:" in
  *":${_mcp_dir}:"*) ;;
  *) export PATH="${_mcp_dir}:${PATH}" ;;
esac

echo "atlasopenmagic-mcp v$(cat "${_mcp_dir}/../VERSION" 2>/dev/null || echo unknown) ready"

unset _mcp_dir
SETUP_EOF
chmod +x "${STAGE}/bin/setup.sh"

# ---------------------------------------------------------------------------
# Publish to CVMFS
# ---------------------------------------------------------------------------
echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu

cd "$MOUNTPOINT"

if [ -d "$TARGET_DIR" ]; then
  if [ "$FORCE" = true ]; then
    echo "Directory $TARGET_DIR exists. Force flag enabled — removing..."
    rm -rf "$TARGET_DIR"
  else
    echo "Directory $TARGET_DIR already exists. Use -f to overwrite."
    cvmfs_server abort sw.escape.eu
    exit 1
  fi
fi

echo "Deploying to ${TARGET_DIR}..."
mkdir -p "$(dirname "$TARGET_DIR")"
cp -a "${STAGE}" "${MOUNTPOINT}/${TARGET_DIR}"

# Update latest symlink
ln -sfn "${VERSION}" "${LATEST_LINK}"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done. Published atlasopenmagic-mcp v${VERSION}"
echo ""
echo "To use with lumi, add to opencode.json:"
echo '  "mcp": {'
echo '    "atlas-opendata": {'
echo '      "type": "local",'
echo '      "command": ["/cvmfs/sw.escape.eu/atlasopenmagic-mcp/latest/bin/atlasopenmagic-mcp", "serve"]'
echo '    }'
echo '  }'
