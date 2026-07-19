#!/bin/bash

# Usage:
#   ./atlasopenmagic-cvmfs-updater.sh [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
#
# Options:
#   -f, --force    Replace existing folder if it exists
#
# Mirrors the helper scripts in rucio/ and rucio-jupyterlab/.

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
VERSION="${3:-${VERSION:-}}"

if [[ -z "$TOKEN" || -z "$ID" ]]; then
  echo "Error: TOKEN and ID must be provided either as arguments or environment variables."
  echo "Usage: $0 [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]"
  echo "If VERSION is omitted, it is derived from the tarball inside the artifact."
  exit 1
fi

REPO_URL="https://api.github.com/repos/vre-hub/escape-cvmfs/actions/artifacts/${ID}/zip"
MOUNTPOINT="/cvmfs/sw.escape.eu"

echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu

cd "$MOUNTPOINT"

echo "Downloading GitHub artifact..."
curl -Ls \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$REPO_URL" -o artifact.zip

echo "Unzipping artifact..."
unzip artifact.zip

# Derive the version from the extracted tarball name if not given explicitly
if [[ -z "$VERSION" ]]; then
  tarball="$(ls atlasopenmagic-*.tar.gz 2>/dev/null | head -n 1)"
  if [[ -z "$tarball" ]]; then
    echo "Error: No atlasopenmagic-*.tar.gz found in the artifact and no VERSION given."
    cvmfs_server abort -f sw.escape.eu
    exit 1
  fi
  VERSION="${tarball#atlasopenmagic-}"
  VERSION="${VERSION%.tar.gz}"
  echo "Derived version from artifact: $VERSION"
fi

PACKAGE_NAME="atlasopenmagic-${VERSION}.tar.gz"
TARGET_DIR="atlasopenmagic/${VERSION}"

if [ -d "$TARGET_DIR" ]; then
  if [ "$FORCE" = true ]; then
    echo "Directory $TARGET_DIR already exists. Force flag enabled - removing existing directory..."
    rm -rf "$TARGET_DIR"
  else
    echo "Directory $TARGET_DIR already exists. Exiting."
    echo "If you are sure to erase this published CVMFS repository, use the -f or --force flag."
    exit 1
  fi
fi

echo "Creating target directory..."
mkdir -p "$TARGET_DIR"

echo "Extracting tarball..."
tar -xvzf "$PACKAGE_NAME" -C "$TARGET_DIR"

echo "Updating 'latest' symlink..."
ln -sfn "$VERSION" atlasopenmagic/latest

echo "Cleaning up temporary files..."
rm -rf artifact.zip "$PACKAGE_NAME"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done."

