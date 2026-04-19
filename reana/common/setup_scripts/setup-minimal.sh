#!/bin/bash
#!----------------------------------------------------------------------------
#!
#! setup-minimal.sh
#!
#!
#! History:
#!   19Apr26: G. Guerrieri: First version
#!
#!----------------------------------------------------------------------------

# Minimal setup for REANA client environment

# Determine shell type (bash/zsh) for path handling
shell_type="bash"
ps -o command= $$ 2>/dev/null | grep -q zsh && shell_type="zsh"

# Set REANA_HOME if not already set
if [ -z "$REANA_HOME" ]; then
    if [ "$shell_type" = "zsh" ]; then
        export REANA_HOME="$(cd "$(dirname "$0")" && pwd)"
    else
        export REANA_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    echo "INFO: Set REANA_HOME to $REANA_HOME"
fi

# Set python binary, default to 'python3' if not set
export REANA_PYTHONBIN="${REANA_PYTHONBIN:-python3}"

# Verify that the Python binary exists and is usable
if ! command -v "$REANA_PYTHONBIN" >/dev/null 2>&1; then
    echo "ERROR: Python binary '$REANA_PYTHONBIN' not found in PATH."
    return 64
fi

# Ensure Python version is >= 3.9
version=$($REANA_PYTHONBIN -c 'import sys; print("%d%02d" % sys.version_info[:2])')
if [ "$version" -lt 309 ]; then
    echo "ERROR: Python version must be >= 3.9 (found $($REANA_PYTHONBIN -V 2>&1))"
    return 64
fi

# Determine major.minor Python version
pyver=$($REANA_PYTHONBIN -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')

# Find the correct site-packages path
sitepkgs=$(find "$REANA_HOME/lib" -mindepth 2 -maxdepth 2 -name site-packages | grep "python$pyver")
if [ -z "$sitepkgs" ]; then
    echo "ERROR: Could not locate site-packages directory for Python $pyver in $REANA_HOME/lib"
    return 64
fi

# Update PATH and PYTHONPATH
export PATH="$REANA_HOME/bin:$PATH"
export PYTHONPATH="$sitepkgs:$PYTHONPATH"

# Clear the command hash table to ensure the shell uses the updated PATH
hash -r 2>/dev/null || true

# Optional: Bash autocompletion for reana-client
if [ "$shell_type" = "bash" ]; then
    eval "$(register-python-argcomplete reana-client 2>/dev/null)"
fi

echo "INFO: REANA client environment is set up."
