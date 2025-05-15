#!/bin/bash
#!----------------------------------------------------------------------------
#!
#! setup-minimal.sh
#!
#!
#! History:
#!   15May25: G. Guerrieri: First version  
#!
#!----------------------------------------------------------------------------

# Minimal setup for Rucio client environment

# Determine shell type (bash/zsh) for path handling
shell_type="bash"
ps -o command= $$ 2>/dev/null | grep -q zsh && shell_type="zsh"

# Set RUCIO_HOME if not already set
if [ -z "$RUCIO_HOME" ]; then
    if [ "$shell_type" = "zsh" ]; then
        export RUCIO_HOME="$(cd "$(dirname "$0")" && pwd)"
    else
        export RUCIO_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    echo "INFO: Set RUCIO_HOME to $RUCIO_HOME"
fi

# Set python binary, default to 'python' if not set
export RUCIO_PYTHONBIN="${RUCIO_PYTHONBIN:-python}"

# Verify that the Python binary exists and is usable
if ! command -v "$RUCIO_PYTHONBIN" >/dev/null 2>&1; then
    echo "ERROR: Python binary '$RUCIO_PYTHONBIN' not found in PATH."
    return 64
fi

# Ensure Python version is >= 2.7
version=$($RUCIO_PYTHONBIN -c 'import sys; print("%d%02d" % sys.version_info[:2])')
if [ "$version" -lt 207 ]; then
    echo "ERROR: Python version must be >= 2.7"
    return 64
fi

# Determine major.minor Python version
pyver=$($RUCIO_PYTHONBIN -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')

# Find the correct site-packages path
sitepkgs=$(find "$RUCIO_HOME/lib" -mindepth 2 -maxdepth 2 -name site-packages | grep "python$pyver")
if [ -z "$sitepkgs" ]; then
    echo "ERROR: Could not locate site-packages directory for Python $pyver in $RUCIO_HOME/lib"
    return 64
fi

# Update PATH and PYTHONPATH
export PATH="$RUCIO_HOME/bin:$PATH"
export PYTHONPATH="$sitepkgs:$PYTHONPATH"

# Optional: Bash autocompletion for rucio clients
if [ "$shell_type" = "bash" ]; then
    eval "$(register-python-argcomplete rucio 2>/dev/null)"
    eval "$(register-python-argcomplete rucio-admin 2>/dev/null)"
fi

echo "INFO: Rucio client environment is set up."
