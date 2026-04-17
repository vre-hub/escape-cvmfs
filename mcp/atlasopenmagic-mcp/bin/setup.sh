#!/usr/bin/env bash
# atlasopenmagic-mcp CVMFS setup — source to put atlasopenmagic-mcp on $PATH.
# Usage: source /cvmfs/sw.escape.eu/mcp/atlasopenmagic-mcp/latest/bin/setup.sh

_mcp_dir="/cvmfs/sw.escape.eu/mcp/atlasopenmagic-mcp/latest/bin"

case ":${PATH}:" in
  *":${_mcp_dir}:"*) ;;
  *) export PATH="${_mcp_dir}:${PATH}" ;;
esac

echo "atlasopenmagic-mcp v$(cat "${_mcp_dir}/../VERSION" 2>/dev/null || echo unknown) ready"
unset _mcp_dir
