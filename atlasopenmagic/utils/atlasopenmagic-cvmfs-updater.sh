#!/bin/bash

# Usage:
#   ./atlasopenmagic-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
#
# Mirrors the helper scripts in rucio/ and rucio-jupyterlab/.

set -euo pipefail

TOKEN="${1:-${TOKEN:-}}"
ID="${2:-${ID:-}}"
VERSION="${3:-${VERSION:-analysis-2025.11}}"

if [[ -z "$TOKEN" || -z "$ID" ]]; then
  echo "Error: TOKEN and ID must be provided either as arguments or environment variables."
  echo "Usage: $0 <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]"
  exit 1
fi

REPO_URL="https://api.github.com/repos/vre-hub/escape-cvmfs/actions/artifacts/${ID}/zip"
MOUNTPOINT="/cvmfs/sw.escape.eu"
PACKAGE_NAME="atlasopenmagic-${VERSION}.tar.gz"
TARGET_DIR="atlasopenmagic/${VERSION}"

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

if [ -d "$TARGET_DIR" ]; then
  echo "Directory $TARGET_DIR already exists. Exiting."
  echo "If you are sure to erase this published CVMFS repository, please do it manually."
  exit 1
fi

echo "Creating target directory..."
mkdir -p "$TARGET_DIR"

echo "Extracting tarball..."
tar -xvzf "$PACKAGE_NAME" -C "$TARGET_DIR"

echo "Cleaning up temporary files..."
rm -rf artifact.zip "$PACKAGE_NAME"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done."

