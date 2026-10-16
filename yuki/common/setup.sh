#!/usr/bin/env bash
# Source this file to activate Yuki's immutable runtime from CVMFS.

if [[ -n "${BASH_VERSION:-}" ]]; then
  _yuki_setup_source="${BASH_SOURCE[0]}"
elif [[ -n "${ZSH_VERSION:-}" ]]; then
  _yuki_setup_source="${(%):-%N}"
else
  _yuki_setup_source="$0"
fi
_yuki_root="$(cd "$(dirname "$_yuki_setup_source")" && pwd)"
_yuki_lcg_python="/cvmfs/sft.cern.ch/lcg/views/LCG_107/x86_64-el9-gcc13-opt/bin/python3"

if [[ -z "${YUKI_PYTHONBIN:-}" ]]; then
  if [[ -x "$_yuki_lcg_python" ]]; then
    export YUKI_PYTHONBIN="$_yuki_lcg_python"
  elif command -v python3.11 >/dev/null 2>&1; then
    export YUKI_PYTHONBIN="$(command -v python3.11)"
  else
    echo "ERROR: Yuki requires Python 3.11; neither LCG 107 nor python3.11 was found." >&2
    unset _yuki_root _yuki_lcg_python
    return 1 2>/dev/null || exit 1
  fi
fi

case ":${PATH}:" in
  *":${_yuki_root}/bin:"*) ;;
  *) export PATH="${_yuki_root}/bin:${PATH}" ;;
esac

_yuki_site="${_yuki_root}/lib/python3.11/site-packages"
case ":${PYTHONPATH:-}:" in
  *":${_yuki_site}:"*) ;;
  *) export PYTHONPATH="${_yuki_site}${PYTHONPATH:+:${PYTHONPATH}}" ;;
esac

export YUKI_HOME="$_yuki_root"
export YUKI_CVMFS_ROOT="$_yuki_root"
export YUKI_VERSION="$(cat "${_yuki_root}/VERSION" 2>/dev/null || echo unknown)"
export YUKIDIR="${YUKIDIR:-$HOME/.Yuki}"

unset _yuki_root _yuki_lcg_python _yuki_site _yuki_setup_source
