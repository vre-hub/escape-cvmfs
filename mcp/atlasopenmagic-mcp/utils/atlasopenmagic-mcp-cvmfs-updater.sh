#!/bin/bash
#
# atlasopenmagic-mcp-cvmfs-updater.sh — Deploy the MCP server tarball to CVMFS
#
# Usage:
#   ./atlasopenmagic-mcp-cvmfs-updater.sh [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
#
# Options:
#   -f, --force    Replace existing version if it exists
#
# The tarball is built by the build_atlasopenmagic_mcp_tarball CI workflow.
# This script downloads the artifact, extracts it, and publishes to CVMFS.
#
# The MCP server uses LCG Python 3.11 from /cvmfs/sft.cern.ch.
#
# MCP servers live under /cvmfs/sw.escape.eu/mcp/<name>/<version>/ (namespace
# introduced 2026-04). For backwards-compatibility the top-level path
# /cvmfs/sw.escape.eu/atlasopenmagic-mcp is kept as a symlink pointing to
# mcp/atlasopenmagic-mcp, so any old references (lumi configs, user docs)
# keep working. The migration is one-shot: on first run against a publisher
# that still has the old directory, this script moves it into mcp/ and
# replaces the top-level with a symlink, inside the same CVMFS transaction.
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

TOKEN="${1:-${TOKEN:-}}"
ID="${2:-${ID:-}}"
VERSION="${3:-}"

if [[ -z "$TOKEN" || -z "$ID" ]]; then
  echo "Error: TOKEN and ARTIFACT_ID must be provided."
  echo "Usage: $0 [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]"
  exit 1
fi

MOUNTPOINT="/cvmfs/sw.escape.eu"
NAMESPACE="mcp"
PACKAGE="atlasopenmagic-mcp"
REPO_URL="https://api.github.com/repos/vre-hub/escape-cvmfs/actions/artifacts/${ID}/zip"

# ---------------------------------------------------------------------------
# Download and extract artifact
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading GitHub artifact ${ID}..."
curl -Ls \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$REPO_URL" -o "${TMPDIR}/artifact.zip"

cd "${TMPDIR}"
unzip -q artifact.zip

TARBALL=$(ls atlasopenmagic-mcp-*.tar.gz 2>/dev/null | head -1)
if [[ -z "$TARBALL" ]]; then
  echo "ERROR: No atlasopenmagic-mcp-*.tar.gz found in artifact"
  ls -la
  exit 1
fi

# Extract version from tarball name if not provided
if [[ -z "$VERSION" ]]; then
  VERSION=$(echo "$TARBALL" | sed 's/^atlasopenmagic-mcp-//; s/\.tar\.gz$//')
  echo "Auto-detected version: ${VERSION}"
fi

mkdir -p extracted
tar -xzf "$TARBALL" -C extracted

cd - >/dev/null

# ---------------------------------------------------------------------------
# Publish to CVMFS (under mcp/ namespace, with back-compat symlink)
# ---------------------------------------------------------------------------
TARGET_DIR="${NAMESPACE}/${PACKAGE}/${VERSION}"
LATEST_LINK="${NAMESPACE}/${PACKAGE}/latest"
LEGACY_LINK="${PACKAGE}"   # /cvmfs/sw.escape.eu/atlasopenmagic-mcp -> mcp/atlasopenmagic-mcp

echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu

cd "$MOUNTPOINT"

# --- One-shot migration: old top-level layout -> nested under mcp/ -----------
# Three possible states for $LEGACY_LINK at the mountpoint:
#   1. Missing entirely              -> create as symlink after the new dir lands
#   2. Real directory with old versions -> move its contents into mcp/<pkg>/, then symlink
#   3. Already a symlink              -> nothing to do (validate target)
if [ -L "$LEGACY_LINK" ]; then
  target="$(readlink "$LEGACY_LINK")"
  if [ "$target" != "${NAMESPACE}/${PACKAGE}" ]; then
    echo "WARNING: legacy path ${LEGACY_LINK} is a symlink to '${target}'"
    echo "         (expected '${NAMESPACE}/${PACKAGE}'). Not touching it."
  fi
elif [ -d "$LEGACY_LINK" ]; then
  # Real directory -> migrate
  echo "Migrating legacy ${LEGACY_LINK}/ -> ${NAMESPACE}/${PACKAGE}/"
  mkdir -p "$NAMESPACE"
  if [ -e "${NAMESPACE}/${PACKAGE}" ]; then
    echo "ERROR: ${NAMESPACE}/${PACKAGE} already exists; cannot safely merge."
    echo "       Inspect and resolve manually, then re-run."
    cvmfs_server abort sw.escape.eu
    exit 1
  fi
  mv "$LEGACY_LINK" "${NAMESPACE}/${PACKAGE}"
  ln -sfn "${NAMESPACE}/${PACKAGE}" "$LEGACY_LINK"
  echo "  -> migrated, ${LEGACY_LINK} is now a symlink."
fi

# Ensure namespace dir exists (first publish or post-migration)
mkdir -p "${NAMESPACE}/${PACKAGE}"

if [ -d "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
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
mkdir -p "$TARGET_DIR"
cp -a "${TMPDIR}/extracted/"* "${TARGET_DIR}/"

# Update latest symlink (inside mcp/)
ln -sfn "${VERSION}" "${LATEST_LINK}"

# Ensure the legacy top-level symlink exists (for anyone still using the old path)
if [ ! -e "$LEGACY_LINK" ]; then
  ln -sfn "${NAMESPACE}/${PACKAGE}" "$LEGACY_LINK"
  echo "Created legacy compatibility symlink: ${LEGACY_LINK} -> ${NAMESPACE}/${PACKAGE}"
fi

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done. Published atlasopenmagic-mcp v${VERSION}"
echo ""
echo "CVMFS layout:"
echo "  ${MOUNTPOINT}/${TARGET_DIR}/bin/atlasopenmagic-mcp  (wrapper, uses LCG Python 3.11)"
echo "  ${MOUNTPOINT}/${TARGET_DIR}/lib/python3.11/site-packages/  (dependencies)"
echo "  ${MOUNTPOINT}/${LATEST_LINK} -> ${VERSION}"
echo "  ${MOUNTPOINT}/${LEGACY_LINK} -> ${NAMESPACE}/${PACKAGE}   (back-compat)"
echo ""
echo "To use with lumi (local stdio):"
echo '  "mcp": {'
echo '    "atlas-opendata": {'
echo '      "type": "local",'
echo "      \"command\": [\"${MOUNTPOINT}/${LATEST_LINK}/bin/atlasopenmagic-mcp\", \"serve\"]"
echo '    }'
echo '  }'
echo ""
echo "Or use the remote server (no CVMFS needed):"
echo '  "mcp": {'
echo '    "atlas-opendata": {'
echo '      "type": "remote",'
echo '      "url": "https://atlasopenmagic-mcp.app.cern.ch/mcp"'
echo '    }'
echo '  }'
