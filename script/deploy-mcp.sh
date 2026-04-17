#!/usr/bin/env bash
# deploy-mcp.sh — extract an MCP tarball into CVMFS and flip the `latest` symlink.
#
# Usage: deploy-mcp.sh <mcp-name> <version> <tarball>
# Example: deploy-mcp.sh root-mcp 0.3.2 root-mcp-0.3.2.tar.gz
#
# Run this on the CVMFS publisher (Stratum-0). The script opens a transaction,
# extracts the tarball into mcp/<name>/<version>/, repoints mcp/<name>/latest,
# and publishes. On any error it aborts the transaction.

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <mcp-name> <version> <tarball>" >&2
  exit 1
fi

NAME="$1"
VERSION="$2"
TARBALL="$3"
REPO="${CVMFS_REPO:-sw.escape.eu}"
DEST="/cvmfs/${REPO}/mcp/${NAME}"

if [ ! -f "$TARBALL" ]; then
  echo "ERROR: tarball not found: $TARBALL" >&2
  exit 1
fi

cvmfs_server transaction "$REPO"
trap 'cvmfs_server abort -f "$REPO"' ERR

mkdir -p "${DEST}/${VERSION}"
tar -xzf "$TARBALL" -C "${DEST}/${VERSION}"
ln -sfn "$VERSION" "${DEST}/latest"

trap - ERR
cvmfs_server publish "$REPO"

echo "Deployed ${NAME} ${VERSION} to ${DEST}/${VERSION} (latest -> ${VERSION})"
