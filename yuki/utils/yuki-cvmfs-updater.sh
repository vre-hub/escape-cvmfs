#!/usr/bin/env bash

set -euo pipefail

FORCE=false
if [[ "${1:-}" == "-f" || "${1:-}" == "--force" ]]; then
  FORCE=true
  shift
fi

TOKEN="${1:-${TOKEN:-}}"
ID="${2:-${ID:-}}"
if [[ -z "$TOKEN" || -z "$ID" ]]; then
  echo "Usage: $0 [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID>" >&2
  exit 2
fi

REPO="${CVMFS_REPO:-sw.escape.eu}"
MOUNTPOINT="/cvmfs/$REPO"
WORK="$(mktemp -d)"
TRANSACTION=false
cleanup() {
  status=$?
  if [[ "$status" -ne 0 && "$TRANSACTION" == true ]]; then
    cvmfs_server abort -f "$REPO" || true
  fi
  rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT

curl -fLsS \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/CelebiProjects/escape-cvmfs/actions/artifacts/${ID}/zip" \
  -o "$WORK/artifact.zip"
unzip -q "$WORK/artifact.zip" -d "$WORK/artifact"

mapfile -t archives < <(find "$WORK/artifact" -type f -name 'yuki-*.tar.gz')
[[ "${#archives[@]}" -eq 1 ]] || { echo "ERROR: expected exactly one Yuki tarball." >&2; exit 1; }
ARCHIVE="${archives[0]}"
CHECKSUM="${ARCHIVE}.sha256"
if [[ -f "$CHECKSUM" ]]; then
  (cd "$(dirname "$ARCHIVE")" && sha256sum -c "$(basename "$CHECKSUM")")
fi

LABEL="$(basename "$ARCHIVE")"
LABEL="${LABEL#yuki-}"
LABEL="${LABEL%.tar.gz}"
TARGET="$MOUNTPOINT/yuki/$LABEL"

cvmfs_server transaction "$REPO"
TRANSACTION=true
if [[ -e "$TARGET" ]]; then
  [[ "$FORCE" == true ]] || { echo "ERROR: $TARGET already exists; use --force to replace it." >&2; exit 1; }
  rm -rf "$TARGET"
fi
mkdir -p "$TARGET"
tar -xzf "$ARCHIVE" -C "$TARGET"
chmod -R a+rX "$TARGET"
ln -sfn "$LABEL" "$MOUNTPOINT/yuki/latest"
cvmfs_server publish "$REPO"
TRANSACTION=false

echo "Published Yuki $LABEL to $TARGET"
