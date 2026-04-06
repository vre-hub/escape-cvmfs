#!/bin/bash
#
# lumi-cvmfs-updater.sh — Download a lumi release and publish to CVMFS
#
# Usage:
#   ./lumi-cvmfs-updater.sh [-f|--force] <VERSION>
#
# Options:
#   -f, --force    Replace existing version if it exists
#
# This script:
#   1. Builds lumi from the opencode repo (or downloads a pre-built binary)
#   2. Stages the versioned directory with setup.sh and symlinks
#   3. Publishes to /cvmfs/sw.escape.eu/lumi/
#
# Mirrors the pattern used by atlasopenmagic/ and rucio/ in this repo.
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
  echo "Example: $0 1.3.15"
  exit 1
fi

MOUNTPOINT="/cvmfs/sw.escape.eu"
TARGET_DIR="lumi/${VERSION}"
LATEST_LINK="lumi/latest"

# ---------------------------------------------------------------------------
# Build or download the binary
# ---------------------------------------------------------------------------
# Option 1: Build from local repo (if OPENCODE_REPO is set)
# Option 2: Download from GitHub releases
BINARY=""
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if [[ -n "${OPENCODE_REPO:-}" ]]; then
  echo "Building lumi from ${OPENCODE_REPO}..."
  cd "${OPENCODE_REPO}/packages/opencode"
  bun run build --single
  BINARY=$(find dist -name "opencode" -type f ! -name "*.exe" | head -1)
  if [[ -z "$BINARY" ]]; then
    echo "ERROR: Build failed — binary not found"
    exit 1
  fi
  BINARY="$(cd "$(dirname "$BINARY")" && pwd)/$(basename "$BINARY")"
  cd -
else
  echo "Downloading lumi v${VERSION} from GitHub..."
  # Determine platform
  ARCH="$(uname -m)"
  case "$ARCH" in
    x86_64) ARCH="x64" ;;
    aarch64|arm64) ARCH="arm64" ;;
  esac
  TARBALL="opencode-linux-${ARCH}.tar.gz"
  RELEASE_URL="https://github.com/Soap2G/opencode/releases/download/v${VERSION}/${TARBALL}"

  curl -fSL "$RELEASE_URL" -o "${TMPDIR}/${TARBALL}" || {
    echo "ERROR: Failed to download ${RELEASE_URL}"
    echo "Set OPENCODE_REPO=/path/to/opencode to build from source instead."
    exit 1
  }
  tar -xzf "${TMPDIR}/${TARBALL}" -C "${TMPDIR}"
  BINARY="${TMPDIR}/opencode"
  if [[ ! -f "$BINARY" ]]; then
    echo "ERROR: Binary not found in tarball"
    exit 1
  fi
fi

echo "Binary: ${BINARY}"

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

echo "Creating ${TARGET_DIR}..."
mkdir -p "${TARGET_DIR}/bin"

cp "$BINARY" "${TARGET_DIR}/bin/opencode"
chmod +x "${TARGET_DIR}/bin/opencode"
ln -sf opencode "${TARGET_DIR}/bin/lumi"

# Write version marker
echo "${VERSION}" > "${TARGET_DIR}/VERSION"

# Write setup.sh
cat > "${TARGET_DIR}/bin/setup.sh" << 'SETUP_EOF'
#!/usr/bin/env bash
# Lumi setup script for CVMFS
# Usage: source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh

_lumi_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Add lumi to PATH (idempotent)
case ":${PATH}:" in
  *":${_lumi_dir}:"*) ;;
  *) export PATH="${_lumi_dir}:${PATH}" ;;
esac

# Lumi version info
export LUMI_VERSION="$(cat "${_lumi_dir}/../VERSION" 2>/dev/null || echo unknown)"

# Prevent opencode's built-in auto-update (we manage versions via CVMFS)
export OPENCODE_DISABLE_AUTOUPDATE=1

# Load LiteLLM API key from per-user file if it exists
if [ -z "${LITELLM_API_KEY:-}" ] && [ -f "$HOME/.lumi/litellm-key" ]; then
  export LITELLM_API_KEY="$(cat "$HOME/.lumi/litellm-key")"
fi

echo "lumi v${LUMI_VERSION} ready"

unset _lumi_dir
SETUP_EOF
chmod +x "${TARGET_DIR}/bin/setup.sh"

# Update the "latest" symlink
ln -sfn "${VERSION}" "${LATEST_LINK}"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done. Published lumi v${VERSION} to ${MOUNTPOINT}/${TARGET_DIR}"
echo "Users can now run:"
echo "  source ${MOUNTPOINT}/${LATEST_LINK}/bin/setup.sh"
