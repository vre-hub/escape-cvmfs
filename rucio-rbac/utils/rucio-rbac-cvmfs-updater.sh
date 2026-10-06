#!/bin/bash

# Publishes the RBAC rucio-clients tarball on CVMFS (sw.escape.eu), in rucio/<LABEL>.
#
# Usage:
#   Tarball from the GitHub Actions artifact (workflow "Build Rucio RBAC Clients Tarball"):
#     ./rucio-rbac-cvmfs-updater.sh [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [LABEL]
#   Tarball that you copied to this machine (for example from the artifact zip, with scp):
#     ./rucio-rbac-cvmfs-updater.sh [-f|--force] -t <rucio-clients-LABEL.tar.gz> [LABEL]
#
# Options:
#   -f, --force        Replace the folder if it exists
#   -t, --tarball FILE Use this tarball. No download. If FILE.sha256 is next to it, it is checked.
#
# or set environment variables: TOKEN=... ID=... LABEL=... ./rucio-rbac-cvmfs-updater.sh
#
# LABEL is the folder name, for example 41.1.1-rbac-7273054bfdc4. For -t, it is taken from the file name
# when you do not give it.

set -euo pipefail

FORCE=false
LOCAL_TARBALL=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE=true
      shift
      ;;
    -t|--tarball)
      LOCAL_TARBALL="$(readlink -f "${2:?--tarball needs a file}")"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

MOUNTPOINT="${CVMFS_MOUNTPOINT:-/cvmfs/sw.escape.eu}"   # the variable is for tests only

if [[ -n "$LOCAL_TARBALL" ]]; then
  [[ -f "$LOCAL_TARBALL" ]] || { echo "Error: $LOCAL_TARBALL not found."; exit 1; }
  derived="$(basename "$LOCAL_TARBALL" .tar.gz)"
  LABEL="${1:-${LABEL:-${derived#rucio-clients-}}}"
else
  TOKEN="${1:-${TOKEN:-}}"
  ID="${2:-${ID:-}}"
  LABEL="${3:-${LABEL:-41.1.1-rbac-7273054bfdc4}}"
  if [[ -z "$TOKEN" || -z "$ID" ]]; then
    echo "Error: TOKEN and ID must be provided either as arguments or environment variables."
    echo "Usage: $0 [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [LABEL]"
    echo "   or: $0 [-f|--force] -t <rucio-clients-LABEL.tar.gz> [LABEL]"
    exit 1
  fi
  REPO_URL="https://api.github.com/repos/vre-hub/cvmfs/actions/artifacts/${ID}/zip"
fi

PACKAGE_NAME="rucio-clients-${LABEL}.tar.gz"
TARGET_DIR="rucio/${LABEL}"

# Everything that can fail without touching CVMFS comes first.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ -n "$LOCAL_TARBALL" ]]; then
  cp "$LOCAL_TARBALL" "$WORK/$PACKAGE_NAME"
  [[ -f "$LOCAL_TARBALL.sha256" ]] && cp "$LOCAL_TARBALL.sha256" "$WORK/$PACKAGE_NAME.sha256"
else
  echo "Downloading GitHub artifact..."
  curl -fLs \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$REPO_URL" -o "$WORK/artifact.zip"
  echo "Unzipping artifact..."
  unzip -q "$WORK/artifact.zip" -d "$WORK"
fi

[[ -f "$WORK/$PACKAGE_NAME" ]] || { echo "Error: $PACKAGE_NAME is not in the artifact. Is LABEL right?"; ls "$WORK"; exit 1; }

if [[ -f "$WORK/$PACKAGE_NAME.sha256" ]]; then
  echo "Checking the checksum..."
  (cd "$WORK" && sha256sum -c "$PACKAGE_NAME.sha256")
else
  echo "WARNING: no .sha256 file; the tarball is not checked."
fi

echo "Starting CVMFS transaction..."
cvmfs_server transaction sw.escape.eu
trap 'rm -rf "$WORK"; echo "Failed. Aborting the CVMFS transaction."; cvmfs_server abort -f sw.escape.eu' ERR

cd "$MOUNTPOINT"

if [ -d "$TARGET_DIR" ]; then
  if [ "$FORCE" = true ]; then
    echo "Directory $TARGET_DIR already exists. Force flag enabled - removing existing directory..."
    rm -rf "$TARGET_DIR"
  else
    echo "Directory $TARGET_DIR already exists. Exiting."
    echo "If you are sure to erase this published CVMFS directory, use the -f or --force flag."
    trap 'rm -rf "$WORK"' ERR
    cd "$HOME"
    cvmfs_server abort -f sw.escape.eu
    exit 1
  fi
fi

echo "Creating target directory..."
mkdir -p "$TARGET_DIR"

echo "Extracting tarball..."
tar -xzf "$WORK/$PACKAGE_NAME" -C "$TARGET_DIR"

echo "Setting permissions..."
chmod -R a+rX "$TARGET_DIR"

cd "$HOME"

echo "Publishing CVMFS..."
cvmfs_server publish sw.escape.eu

echo "Done. rucio-clients $LABEL deployed to $MOUNTPOINT/$TARGET_DIR"
echo "Use:  source $MOUNTPOINT/$TARGET_DIR/setup-tutorial.sh [<rucio account>]"
