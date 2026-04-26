#!/bin/bash
#
# lumi-cvmfs-updater.sh — Deploy a lumi binary to CVMFS
#
# Usage:
#   ./lumi-cvmfs-updater.sh [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
#   OPENCODE_REPO=/path/to/opencode ./lumi-cvmfs-updater.sh [-f|--force] [VERSION]
#
# Modes:
#   1. GitHub artifact: provide TOKEN + ARTIFACT_ID (from build_lumi_binary workflow)
#   2. Local build:     set OPENCODE_REPO env var (must run `bun install` from repo root first)
#
# Options:
#   -f, --force    Replace existing version if it exists
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

MOUNTPOINT="/cvmfs/sw.escape.eu"
REPO_URL_BASE="https://api.github.com/repos/vre-hub/escape-cvmfs/actions/artifacts"

# ---------------------------------------------------------------------------
# Determine mode and parse arguments
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if [[ -n "${OPENCODE_REPO:-}" ]]; then
  # --- Mode: local build ---
  VERSION="${1:-}"
  if [[ -z "$VERSION" ]]; then
    VERSION=$(node -e "console.log(require('${OPENCODE_REPO}/packages/opencode/package.json').version)")
    echo "Auto-detected version: ${VERSION}"
  fi

  echo "Building lumi from ${OPENCODE_REPO}..."
  echo "  (Reminder: run 'bun install' from the repo root if you haven't already)"

  cd "${OPENCODE_REPO}/packages/opencode"
  bun run build --single
  BINARY=$(find dist -name "opencode" -type f ! -name "*.exe" | head -1)
  if [[ -z "$BINARY" ]]; then
    echo "ERROR: Build failed — binary not found"
    exit 1
  fi
  BINARY="$(cd "$(dirname "$BINARY")" && pwd)/$(basename "$BINARY")"
  cd - >/dev/null

else
  # --- Mode: GitHub artifact ---
  TOKEN="${1:-${TOKEN:-}}"
  ID="${2:-${ID:-}}"
  VERSION="${3:-}"

  if [[ -z "$TOKEN" || -z "$ID" ]]; then
    echo "Error: provide either OPENCODE_REPO or TOKEN + ARTIFACT_ID."
    echo ""
    echo "Usage:"
    echo "  GitHub artifact:  $0 [-f] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]"
    echo "  Local build:      OPENCODE_REPO=/path/to/opencode $0 [-f] [VERSION]"
    exit 1
  fi

  echo "Downloading GitHub artifact ${ID}..."
  curl -Ls \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${REPO_URL_BASE}/${ID}/zip" -o "${TMPDIR}/artifact.zip"

  cd "${TMPDIR}"
  unzip -q artifact.zip

  # The artifact contains a tarball like lumi-1.3.15.tar.gz
  TARBALL=$(ls lumi-*.tar.gz 2>/dev/null | head -1)
  if [[ -z "$TARBALL" ]]; then
    echo "ERROR: No lumi-*.tar.gz found in artifact"
    ls -la
    exit 1
  fi

  # Extract version from tarball name if not provided
  if [[ -z "$VERSION" ]]; then
    VERSION=$(echo "$TARBALL" | sed 's/^lumi-//; s/\.tar\.gz$//')
    echo "Auto-detected version from tarball: ${VERSION}"
  fi

  mkdir -p extracted
  tar -xzf "$TARBALL" -C extracted

  BINARY="${TMPDIR}/extracted/bin/opencode"
  if [[ ! -f "$BINARY" ]]; then
    # Fallback: binary might be at top level
    BINARY=$(find "${TMPDIR}/extracted" -name "opencode" -type f ! -name "*.exe" | head -1)
  fi
  if [[ -z "$BINARY" || ! -f "$BINARY" ]]; then
    echo "ERROR: Binary not found in tarball"
    find "${TMPDIR}/extracted" -type f
    exit 1
  fi
  cd - >/dev/null
fi

echo "Binary: ${BINARY}"
echo "Version: ${VERSION}"

# ---------------------------------------------------------------------------
# Publish to CVMFS
# ---------------------------------------------------------------------------
TARGET_DIR="lumi/${VERSION}"
LATEST_LINK="lumi/latest"

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

# ---------------------------------------------------------------------------
# Deploy shared config directory
# ---------------------------------------------------------------------------
# The config lives in the repo at lumi/config/ and is deployed to a
# version-independent path so it can be updated without re-publishing
# the binary.
CONFIG_SRC="$(cd "$(dirname "$0")/../config" && pwd)"
CONFIG_DST="etc/lumi"

if [ -d "$CONFIG_SRC" ]; then
  echo "Deploying config from ${CONFIG_SRC} to ${CONFIG_DST}..."
  mkdir -p "$CONFIG_DST"
  cp -a "${CONFIG_SRC}/"* "${CONFIG_DST}/"
else
  echo "WARNING: Config directory not found at ${CONFIG_SRC}"
  echo "  The shared config will not be updated."
fi

# Write setup.sh
cat > "${TARGET_DIR}/bin/setup.sh" << 'SETUP_EOF'
#!/usr/bin/env bash
# Lumi setup script for CVMFS
# Usage: source /cvmfs/sw.escape.eu/lumi/latest/bin/setup.sh

_lumi_dir="/cvmfs/sw.escape.eu/lumi/latest/bin"
_lumi_config="/cvmfs/sw.escape.eu/etc/lumi"

# Add lumi to PATH (idempotent)
case ":${PATH}:" in
  *":${_lumi_dir}:"*) ;;
  *) export PATH="${_lumi_dir}:${PATH}" ;;
esac

# Lumi version info
export LUMI_VERSION="$(cat "${_lumi_dir}/../VERSION" 2>/dev/null || echo unknown)"

# Prevent opencode's built-in auto-update (we manage versions via CVMFS)
export OPENCODE_DISABLE_AUTOUPDATE=1

# SQLite WAL mode doesn't work on EOS (no mmap/flock support).
# Store the database on a local filesystem instead.
_lumi_data="/tmp/${USER}-lumi"
mkdir -p "$_lumi_data" 2>/dev/null
export OPENCODE_DB="${_lumi_data}/opencode.db"

# Load shared config directory from CVMFS
# Contains opencode.json, AGENTS.md, and any custom agents/commands/modes.
# User and project configs can still override individual settings.
export OPENCODE_CONFIG_DIR="${_lumi_config}"

# Load atom-assistant setup if available
_atom_setup="/cvmfs/sw.escape.eu/etc/lumi/atom-assistant/latest/bin/setup.sh"
if [ -f "$_atom_setup" ]; then
  source "$_atom_setup"
fi

# Load LiteLLM API key from per-user file if it exists
if [ -z "${LITELLM_API_KEY:-}" ]; then
  if [ -r /eos/user/g/gguerrie/lumi_assistant/key.txt ]; then
    export LITELLM_API_KEY="$(cat /eos/user/g/gguerrie/lumi_assistant/key.txt)"
  else
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                          ⚠️  WARNING  ⚠️                           ║"
    echo "╠════════════════════════════════════════════════════════════════════╣"
    echo "║  LITELLM_API_KEY not set and key file not accessible.              ║"
    echo "║                                                                    ║"
    echo "║  To use lumi, please either:                                       ║"
    echo "║                                                                    ║"
    echo "║  1. Export your own LITELLM_API_KEY environment variable:          ║"
    echo "║     export LITELLM_API_KEY=\"your-api-key-here\"                     ║"
    echo "║                                                                    ║"
    echo "║  2. Request access to the lumi-api-access egroup:                  ║"
    echo "║     https://gms.web.cern.ch/group/lumi-api-access                  ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo ""
  fi
fi

echo "lumi v${LUMI_VERSION} ready  (config: ${_lumi_config})"

unset _lumi_dir _lumi_config _lumi_data
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
