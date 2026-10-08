#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YUKI_SOURCE="${YUKI_SOURCE_DIR:-}"
CELEBI_SOURCE="${CELEBI_SOURCE_DIR:-}"
PYTHON_BIN="${PYTHON_BIN:-python3.11}"
CONDA_BIN="${CONDA_BIN:-conda}"
CONDA_PACK_BIN="${CONDA_PACK_BIN:-conda-pack}"
RABBITMQ_VERSION="${RABBITMQ_VERSION:-}"

if [[ -z "$YUKI_SOURCE" || ! -f "$YUKI_SOURCE/pyproject.toml" ]]; then
  echo "ERROR: set YUKI_SOURCE_DIR to a Yuki source checkout." >&2
  exit 1
fi
if [[ -z "$CELEBI_SOURCE" || ! -f "$CELEBI_SOURCE/pyproject.toml" ]]; then
  echo "ERROR: set CELEBI_SOURCE_DIR to the matching Celebi source checkout." >&2
  exit 1
fi

YUKI_SOURCE="$(cd "$YUKI_SOURCE" && pwd)"
CELEBI_SOURCE="$(cd "$CELEBI_SOURCE" && pwd)"
VERSION="$($PYTHON_BIN - "$YUKI_SOURCE/pyproject.toml" <<'PY'
import pathlib, sys, tomllib
print(tomllib.loads(pathlib.Path(sys.argv[1]).read_text())["project"]["version"])
PY
)"
YUKI_COMMIT="$(git -C "$YUKI_SOURCE" rev-parse --short=12 HEAD)"
CELEBI_COMMIT="$(git -C "$CELEBI_SOURCE" rev-parse --short=12 HEAD)"
LABEL="${YUKI_LABEL:-${VERSION}-${YUKI_COMMIT}}"
[[ "$LABEL" =~ ^[A-Za-z0-9._+-]+$ ]] || { echo "ERROR: invalid release label: $LABEL" >&2; exit 1; }
BUILD_ROOT="$SCRIPT_DIR/build-${LABEL}"
SITE_PACKAGES="$BUILD_ROOT/lib/python3.11/site-packages"
ARCHIVE="$SCRIPT_DIR/yuki-${LABEL}.tar.gz"
CVMFS_PREFIX="${YUKI_CVMFS_PREFIX:-/cvmfs/sw.escape.eu/yuki/${LABEL}}"
RUNTIME_WORK="$(mktemp -d)"
RUNTIME_PREFIX="$RUNTIME_WORK/env"
RUNTIME_ARCHIVE="$RUNTIME_WORK/rabbitmq-runtime.tar.gz"
cleanup() {
  rm -rf "$RUNTIME_WORK"
}
trap cleanup EXIT

rm -rf "$BUILD_ROOT"
mkdir -p "$SITE_PACKAGES" "$BUILD_ROOT/bin"

"$PYTHON_BIN" -m pip install --disable-pip-version-check --no-cache-dir \
  --target "$SITE_PACKAGES" "$CELEBI_SOURCE" "$YUKI_SOURCE"

command -v "$CONDA_BIN" >/dev/null 2>&1 \
  || { echo "ERROR: conda/mamba is required to package RabbitMQ." >&2; exit 1; }
command -v "$CONDA_PACK_BIN" >/dev/null 2>&1 \
  || { echo "ERROR: conda-pack is required to package RabbitMQ." >&2; exit 1; }

RABBITMQ_SPEC="rabbitmq-server${RABBITMQ_VERSION:+=$RABBITMQ_VERSION}"
"$CONDA_BIN" create --yes --prefix "$RUNTIME_PREFIX" \
  --override-channels --channel conda-forge "$RABBITMQ_SPEC"
"$CONDA_PACK_BIN" --prefix "$RUNTIME_PREFIX" \
  --output "$RUNTIME_ARCHIVE" \
  --dest-prefix "$CVMFS_PREFIX/lib/rabbitmq"
mkdir -p "$BUILD_ROOT/lib/rabbitmq"
tar -xzf "$RUNTIME_ARCHIVE" -C "$BUILD_ROOT/lib/rabbitmq"
if [[ -d "$BUILD_ROOT/lib/rabbitmq/lib/erlang" ]]; then
  ln -s rabbitmq/lib/erlang "$BUILD_ROOT/lib/erlang"
fi

if [[ -d "$SITE_PACKAGES/bin" ]]; then
  cp -a "$SITE_PACKAGES/bin/." "$BUILD_ROOT/bin/"
  rm -rf "$SITE_PACKAGES/bin"
fi

for entrypoint in yuki yukirunner yuki-create-data yuki-native-runner; do
  if [[ ! -f "$BUILD_ROOT/bin/$entrypoint" ]]; then
    echo "ERROR: expected console entry point was not installed: $entrypoint" >&2
    exit 1
  fi
  tmpfile="$(mktemp)"
  {
    printf '#!/usr/bin/env bash\n'
    printf '_yuki_bin_dir="$(cd "$(dirname "$0")" && pwd)"\n'
    printf 'exec "${YUKI_PYTHONBIN:?Source setup.sh first}" "${_yuki_bin_dir}/%s.py" "$@"\n' \
      "$entrypoint"
  } > "$tmpfile"
  mv "$tmpfile" "$BUILD_ROOT/bin/${entrypoint}.wrapper"
  mv "$BUILD_ROOT/bin/$entrypoint" "$BUILD_ROOT/bin/${entrypoint}.py"
  mv "$BUILD_ROOT/bin/${entrypoint}.wrapper" "$BUILD_ROOT/bin/$entrypoint"
  chmod +x "$BUILD_ROOT/bin/$entrypoint"
done

cp "$SCRIPT_DIR/common/yuki-service" "$BUILD_ROOT/bin/yuki-service"
cp "$SCRIPT_DIR/common/rabbitmq-server" "$BUILD_ROOT/bin/rabbitmq-server"
cp "$SCRIPT_DIR/common/rabbitmqctl" "$BUILD_ROOT/bin/rabbitmqctl"
chmod +x "$BUILD_ROOT/bin/yuki-service" \
  "$BUILD_ROOT/bin/rabbitmq-server" "$BUILD_ROOT/bin/rabbitmqctl"
cp "$SCRIPT_DIR/common/setup.sh" "$BUILD_ROOT/setup.sh"
printf '%s\n' "$LABEL" > "$BUILD_ROOT/VERSION"
{
  printf 'yuki %s\n' "$YUKI_COMMIT"
  printf 'celebi %s\n' "$CELEBI_COMMIT"
} > "$BUILD_ROOT/SOURCE_COMMIT"
"$CONDA_BIN" list --prefix "$RUNTIME_PREFIX" > "$BUILD_ROOT/RABBITMQ_PACKAGES"

tar -czf "$ARCHIVE" -C "$BUILD_ROOT" .
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$SCRIPT_DIR" && sha256sum "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
else
  (cd "$SCRIPT_DIR" && shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
fi

echo "Built $ARCHIVE"
