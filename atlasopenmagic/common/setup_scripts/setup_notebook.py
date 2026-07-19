"""
Setup helper for ATLAS OpenMagic in Jupyter notebooks.
Usage:
    import sys
    sys.path.insert(0, '/cvmfs/sw.escape.eu/atlasopenmagic/latest')
    from setup_notebook import setup_atlasopenmagic
    setup_atlasopenmagic()
"""

import os
import sys
from pathlib import Path
from glob import glob

def setup_atlasopenmagic(atlasopenmagic_home=None):
    """Setup ATLAS OpenMagic environment in Jupyter notebook."""
    
    # Determine ATLASOPENMAGIC_HOME
    if atlasopenmagic_home is None:
        atlasopenmagic_home = os.environ.get('ATLASOPENMAGIC_HOME')
        if atlasopenmagic_home is None:
            # Try to infer from this script's location
            atlasopenmagic_home = str(Path(__file__).parent.absolute())
    
    os.environ['ATLASOPENMAGIC_HOME'] = atlasopenmagic_home
    print(f"INFO: Set ATLASOPENMAGIC_HOME to {atlasopenmagic_home}")
    
    # Get Python version
    pyver = f"{sys.version_info.major}.{sys.version_info.minor}"
    
    # Verify Python version >= 3.10
    if sys.version_info < (3, 10):
        raise RuntimeError("ERROR: Python version must be >= 3.10")
    
    # Find site-packages directory
    lib_path = os.path.join(atlasopenmagic_home, 'lib')
    pattern = os.path.join(lib_path, f'python{pyver}', 'site-packages')
    
    sitepkgs_matches = glob(pattern)
    if not sitepkgs_matches:
        raise RuntimeError(f"ERROR: Could not locate site-packages directory for Python {pyver} in {lib_path}")
    
    sitepkgs = sitepkgs_matches[0]
    
    # Update sys.path (instead of PYTHONPATH)
    if sitepkgs not in sys.path:
        sys.path.insert(0, sitepkgs)
        print(f"INFO: Added {sitepkgs} to sys.path")
    
    # Update PATH environment variable
    bin_path = os.path.join(atlasopenmagic_home, 'bin')
    if bin_path not in os.environ.get('PATH', ''):
        os.environ['PATH'] = f"{bin_path}:{os.environ.get('PATH', '')}"
    
    print("INFO: Finished setting up the ATLAS OpenMagic analysis environment.")
    return sitepkgs
