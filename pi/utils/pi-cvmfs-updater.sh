#!/bin/bash
#
# pi-cvmfs-updater.sh — Deploy the Pi runtime (Node + Pi) to CVMFS
#
# Usage:
#   ./pi-cvmfs-updater.sh [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
#   ./pi-cvmfs-updater.sh [-f|--force] --tarball /path/to/pi-<ver>.tar.gz [VERSION]
#
# Modes:
#   1. GitHub artifact: TOKEN + ARTIFACT_ID (from the build_pi_tarball workflow)
#   2. Local tarball:   --tarball PATH
#
# Options:
#   -f, --force    Replace existing version if it exists
#
# Only the runtime is deployed here. The Lumi config for Pi comes from the
# atom-assistant release; the launcher lives in lumi/bin/lumi-pi.
#
# Mirrors the pattern used by rucio/ and lumi/ in this repo.
#

set -euo pipefail

FORCE=false
LOCAL_TARBALL=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE=true
      shift
      ;;
    --tarball)
      LOCAL_TARBALL="$(cd "$(dirname -- "${2:?--tarball needs a path}")" && pwd)/$(basename -- "$2")"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

MOUNTPOINT="/cvmfs/sw.escape.eu"
REPO_URL_BASE="https://api.github.com/repos/vre-hub/escape-cvmfs/actions/artifacts"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if [[ -n "$LOCAL_TARBALL" ]]; then
  # --- Mode: local tarball ---
  VERSION="${1:-}"
  TARBALL="$LOCAL_TARBALL"
else
  # --- Mode: GitHub artifact ---
  TOKEN="${1:-${TOKEN:-}}"
  ID="${2:-${ID:-}}"
  VERSION="${3:-}"

  if [[ -z "$TOKEN" || -z "$ID" ]]; then
    echo "Error: provide either --tarball PATH or TOKEN + ARTIFACT_ID."
    echo ""
    echo "Usage:"
    echo "  GitHub artifact:  $0 [-f] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]"
    echo "  Local tarball:    $0 [-f] --tarball /path/to/pi-<ver>.tar.gz [VERSION]"
    exit 1
  fi

  echo "Downloading GitHub artifact ${ID}..."
  curl -Ls \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "${REPO_URL_BASE}/${ID}/zip" -o "${TMPDIR}/artifact.zip"

  (cd "$TMPDIR" && unzip -q artifact.zip)
  TARBALL="$(ls "${TMPDIR}"/pi-*.tar.gz 2>/dev/null | head -1 || true)"
  if [[ -z "$TARBALL" ]]; then
    echo "ERROR: No pi-*.tar.gz found in artifact"
    ls -la "$TMPDIR"
    exit 1
  fi
fi

mkdir -p "${TMPDIR}/extracted"
tar -xzf "$TARBALL" -C "${TMPDIR}/extracted"

if [[ ! -x "${TMPDIR}/extracted/bin/pi" || ! -x "${TMPDIR}/extracted/node/bin/node" \
      || ! -f "${TMPDIR}/extracted/VERSION" || ! -f "${TMPDIR}/extracted/NODE_VERSION" ]]; then
  echo "ERROR: tarball is missing bin/pi, node/bin/node, VERSION or NODE_VERSION"
  find "${TMPDIR}/extracted" -maxdepth 2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  VERSION="$(tr -d '[:space:]' < "${TMPDIR}/extracted/VERSION")"
  echo "Auto-detected version from tarball: ${VERSION}"
fi

echo "Version: ${VERSION} (Node $(cat "${TMPDIR}/extracted/NODE_VERSION"))"

# ---------------------------------------------------------------------------
# Publish to CVMFS
# ---------------------------------------------------------------------------
TARGET_DIR="pi/${VERSION}"
LATEST_LINK="pi/latest"

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
mkdir -p "$TARGET_DIR"
cp -a "${TMPDIR}/extracted/." "${TARGET_DIR}/"
chmod -R a+rX "$TARGET_DIR"

ln -sfn "${VERSION}" "${LATEST_LINK}"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done. Published Pi ${VERSION} to ${MOUNTPOINT}/${TARGET_DIR}"
