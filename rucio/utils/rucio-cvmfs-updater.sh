#!/bin/bash

# Usage:
#   ./rucio-cvmfs-updater.sh [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [RUCIO_VERSION]
#
# Options:
#   -f, --force    Replace existing folder if it exists
#
# or set environment variables:
#   TOKEN=... ID=... RUCIO_VERSION=... ./rucio-cvmfs-updater.sh

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
RUCIO_VERSION="${3:-${RUCIO_VERSION:-38.3.0}}"

if [[ -z "$TOKEN" || -z "$ID" ]]; then
  echo "Error: TOKEN and ID must be provided either as arguments or environment variables."
  echo "Usage: $0 [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [RUCIO_VERSION]"
  exit 1
fi

REPO_URL="https://api.github.com/repos/vre-hub/escape-cvmfs/actions/artifacts/${ID}/zip"
MOUNTPOINT="/cvmfs/sw.escape.eu"
PACKAGE_NAME="rucio-clients-${RUCIO_VERSION}.tar.gz"
TARGET_DIR="rucio/${RUCIO_VERSION}"

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
  if [ "$FORCE" = true ]; then
    echo "Directory $TARGET_DIR already exists. Force flag enabled - removing existing directory..."
    rm -rf "$TARGET_DIR"
  else
    echo "Directory $TARGET_DIR already exists. Exiting."
    echo "If you are sure to erase this published CVMFS directory, use the -f or --force flag."
    rm -rf artifact.zip "$PACKAGE_NAME"
    cvmfs_server abort sw.escape.eu
    exit 1
  fi
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

echo "Done. Rucio clients $RUCIO_VERSION deployed to $MOUNTPOINT/$TARGET_DIR"
