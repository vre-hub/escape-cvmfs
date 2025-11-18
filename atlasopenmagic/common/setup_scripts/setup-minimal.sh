#!/bin/bash
#!----------------------------------------------------------------------------
#! setup-minimal.sh
#!----------------------------------------------------------------------------
#! Minimal setup for the ATLAS OpenMagic analysis environment
#!----------------------------------------------------------------------------

# Determine shell type (bash/zsh) for path handling
shell_type="bash"
ps -o command= $$ 2>/dev/null | grep -q zsh && shell_type="zsh"

# Set ATLASOPENMAGIC_HOME if not already set
if [ -z "$ATLASOPENMAGIC_HOME" ]; then
    if [ "$shell_type" = "zsh" ]; then
        export ATLASOPENMAGIC_HOME="$(cd "$(dirname "$0")" && pwd)"
    else
        export ATLASOPENMAGIC_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    echo "INFO: Set ATLASOPENMAGIC_HOME to $ATLASOPENMAGIC_HOME"
fi

# Set python binary, default to 'python' if not set
export ATLASOPENMAGIC_PYTHONBIN="${ATLASOPENMAGIC_PYTHONBIN:-python}"

# Verify that the Python binary exists and is usable
if ! command -v "$ATLASOPENMAGIC_PYTHONBIN" >/dev/null 2>&1; then
    echo "ERROR: Python binary '$ATLASOPENMAGIC_PYTHONBIN' not found in PATH."
    return 64 2>/dev/null || exit 64
fi

# Ensure Python version is >= 3.9 (OpenMagic relies on modern features)
version=$($ATLASOPENMAGIC_PYTHONBIN -c 'import sys; print("%d%02d" % sys.version_info[:2])')
if [ "$version" -lt 309 ]; then
    echo "ERROR: Python version must be >= 3.9"
    return 64 2>/dev/null || exit 64
fi

# Determine major.minor Python version
pyver=$($ATLASOPENMAGIC_PYTHONBIN -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))')

# Find the correct site-packages path
sitepkgs=$(find "$ATLASOPENMAGIC_HOME/lib" -mindepth 2 -maxdepth 2 -name site-packages | grep "python$pyver" | head -n 1)
if [ -z "$sitepkgs" ]; then
    echo "ERROR: Could not locate site-packages directory for Python $pyver in $ATLASOPENMAGIC_HOME/lib"
    return 64 2>/dev/null || exit 64
fi

# Update PATH and PYTHONPATH
export PATH="$ATLASOPENMAGIC_HOME/bin:$PATH"
if [ -z "$PYTHONPATH" ]; then
    export PYTHONPATH="$sitepkgs"
else
    export PYTHONPATH="$PYTHONPATH:$sitepkgs"
fi

echo "INFO: Finished setting up the ATLAS OpenMagic analysis environment."

