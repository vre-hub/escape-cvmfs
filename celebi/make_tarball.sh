#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${CELEBI_SOURCE_DIR:-}"
PYTHON_BIN="${PYTHON_BIN:-python3.11}"

if [[ -z "$SOURCE_DIR" || ! -f "$SOURCE_DIR/pyproject.toml" ]]; then
  echo "ERROR: set CELEBI_SOURCE_DIR to a Celebi source checkout." >&2
  exit 1
fi

SOURCE_DIR="$(cd "$SOURCE_DIR" && pwd)"
VERSION="$($PYTHON_BIN - "$SOURCE_DIR/pyproject.toml" <<'PY'
import pathlib, sys, tomllib
print(tomllib.loads(pathlib.Path(sys.argv[1]).read_text())["project"]["version"])
PY
)"
COMMIT="$(git -C "$SOURCE_DIR" rev-parse --short=12 HEAD)"
LABEL="${CELEBI_LABEL:-${VERSION}-${COMMIT}}"
[[ "$LABEL" =~ ^[A-Za-z0-9._+-]+$ ]] || { echo "ERROR: invalid release label: $LABEL" >&2; exit 1; }
BUILD_ROOT="$SCRIPT_DIR/build-${LABEL}"
SITE_PACKAGES="$BUILD_ROOT/lib/python3.11/site-packages"
ARCHIVE="$SCRIPT_DIR/celebi-${LABEL}.tar.gz"

rm -rf "$BUILD_ROOT"
mkdir -p "$SITE_PACKAGES" "$BUILD_ROOT/bin"

"$PYTHON_BIN" -m pip install --disable-pip-version-check --no-cache-dir \
  --target "$SITE_PACKAGES" "$SOURCE_DIR"

if [[ -d "$SITE_PACKAGES/bin" ]]; then
  cp -a "$SITE_PACKAGES/bin/." "$BUILD_ROOT/bin/"
  rm -rf "$SITE_PACKAGES/bin"
fi

for entrypoint in celebi celebi-cli celebi-git; do
  if [[ ! -f "$BUILD_ROOT/bin/$entrypoint" ]]; then
    echo "ERROR: expected console entry point was not installed: $entrypoint" >&2
    exit 1
  fi
  tmpfile="$(mktemp)"
  {
    printf '#!/usr/bin/env bash\n'
    printf '_celebi_bin_dir="$(cd "$(dirname "$0")" && pwd)"\n'
    printf 'exec "${CELEBI_PYTHONBIN:?Source setup.sh first}" "${_celebi_bin_dir}/%s.py" "$@"\n' \
      "$entrypoint"
  } > "$tmpfile"
  mv "$tmpfile" "$BUILD_ROOT/bin/${entrypoint}.wrapper"
  mv "$BUILD_ROOT/bin/$entrypoint" "$BUILD_ROOT/bin/${entrypoint}.py"
  mv "$BUILD_ROOT/bin/${entrypoint}.wrapper" "$BUILD_ROOT/bin/$entrypoint"
  chmod +x "$BUILD_ROOT/bin/$entrypoint"
done

cp "$SCRIPT_DIR/common/setup.sh" "$BUILD_ROOT/setup.sh"
printf '%s\n' "$LABEL" > "$BUILD_ROOT/VERSION"
printf '%s\n' "$COMMIT" > "$BUILD_ROOT/SOURCE_COMMIT"

tar -czf "$ARCHIVE" -C "$BUILD_ROOT" .
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$SCRIPT_DIR" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
else
  (cd "$SCRIPT_DIR" && shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
fi

echo "Built $ARCHIVE"
