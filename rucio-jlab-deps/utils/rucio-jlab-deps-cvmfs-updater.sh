#!/bin/bash

# Usage:
#   ./deploy_rucio.sh <GITHUB_TOKEN> <ARTIFACT_ID>
# or set environment variables:
#   TOKEN=... ID=... ./deploy_rucio.sh

set -e  # Exit on error
set -u  # Treat unset variables as errors

# Input arguments or environment variables
TOKEN="${1:-${TOKEN:-}}"
ID="${2:-${ID:-}}"
VERSION="${3:-${VERSION:-1.2.0}}"

if [[ -z "$TOKEN" || -z "$ID" ]]; then
  echo "Error: TOKEN and ID must be provided either as arguments or environment variables."
  echo "Usage: $0 <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]"
  exit 1
fi

REPO_URL="https://api.github.com/repos/vre-hub/cvmfs/actions/artifacts/${ID}/zip"
MOUNTPOINT="/cvmfs/sw.escape.eu"
PACKAGE_NAME="rucio-jlab-deps-${VERSION}.tar.gz"
TARGET_DIR="rucio-jlab-deps/${VERSION}"

echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu

cd "$MOUNTPOINT"

echo "Downloading GitHub artifact..."
curl -L \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$REPO_URL" -o artifact.zip

echo "Unzipping artifact..."
unzip artifact.zip

echo "Cleaning old rucio-jlab-deps directory if exists..."
rm -rf rucio-jlab-deps

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
