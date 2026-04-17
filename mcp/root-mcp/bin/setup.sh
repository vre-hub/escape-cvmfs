#!/usr/bin/env bash
# root-mcp CVMFS setup — source to put root-mcp and root-cli on $PATH.
# Usage: source /cvmfs/sw.escape.eu/mcp/root-mcp/latest/bin/setup.sh

_rootmcp_dir="/cvmfs/sw.escape.eu/mcp/root-mcp/latest/bin"

case ":${PATH}:" in
  *":${_rootmcp_dir}:"*) ;;
  *) export PATH="${_rootmcp_dir}:${PATH}" ;;
esac

export ROOT_MCP_VERSION="$(cat "${_rootmcp_dir}/../VERSION" 2>/dev/null || echo unknown)"
echo "root-mcp v${ROOT_MCP_VERSION} ready  (root-mcp, root-cli on PATH)"
unset _rootmcp_dir
