#!/usr/bin/env bash
# Build pi-<version>.tar.gz: Node binary + pinned Pi npm tree + launcher.
#
# Usage: NODE_VERSION=22.23.3 NODE_SHA256=<sha> ./pi/make_tarball.sh
#
# Run it in an EL9 container (almalinux:9) on linux-x64 so the result matches
# lxplus glibc. Needs: curl, tar, xz, sha256sum.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${NODE_VERSION:?set NODE_VERSION (e.g. 22.23.3)}"
: "${NODE_SHA256:?set NODE_SHA256 (sha256 of node-v\${NODE_VERSION}-linux-x64.tar.xz)}"

NODE_DIST="node-v${NODE_VERSION}-linux-x64"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "Downloading ${NODE_DIST}.tar.xz..."
curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/${NODE_DIST}.tar.xz" -o "${WORK}/node.tar.xz"
echo "${NODE_SHA256}  ${WORK}/node.tar.xz" | sha256sum -c -

tar -xJf "${WORK}/node.tar.xz" -C "$WORK"

STAGE="${WORK}/stage"
mkdir -p "${STAGE}/node/bin" "${STAGE}/bin" "${STAGE}/app"

# Ship only the node binary and its license. npm is needed at build time only.
cp "${WORK}/${NODE_DIST}/bin/node" "${STAGE}/node/bin/node"
cp "${WORK}/${NODE_DIST}/LICENSE" "${STAGE}/node/LICENSE"

cp "${SCRIPT_DIR}/app/package.json" "${SCRIPT_DIR}/app/package-lock.json" "${STAGE}/app/"
cp "${SCRIPT_DIR}/bin/pi" "${STAGE}/bin/pi"
chmod +x "${STAGE}/bin/pi"

echo "Installing Pi from the pinned lockfile..."
(
  cd "${STAGE}/app"
  PATH="${WORK}/${NODE_DIST}/bin:${PATH}" npm ci --ignore-scripts --no-audit --no-fund
)

PI_VERSION="$("${STAGE}/node/bin/node" -p "require('${STAGE}/app/package.json').dependencies['@earendil-works/pi-coding-agent']")"
echo "$PI_VERSION" > "${STAGE}/VERSION"
echo "$NODE_VERSION" > "${STAGE}/NODE_VERSION"

TARBALL="${SCRIPT_DIR}/pi-${PI_VERSION}.tar.gz"
tar -czf "$TARBALL" -C "$STAGE" .
echo "Built ${TARBALL}"
