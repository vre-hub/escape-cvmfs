## ATLAS OpenMagic (atom) on CVMFS

Tarball recipe to distribute the [atlasopenmagic](https://pypi.org/project/atlasopenmagic/)
package ("atom") and its runtime dependencies (`pyyaml`, `requests`, `tqdm`) on CVMFS.

Only the package itself is shipped — it is meant to be layered on top of any
existing Python >= 3.10 environment via `PYTHONPATH`, not to replace a full
analysis stack (ROOT, coffea, jupyter, ... come from the hosting image).

### Building

Tarballs are built on demand by the `Build ATLAS OpenMagic Tarball` GitHub
Actions workflow (`workflow_dispatch`): pass a PyPI version, or leave it empty
to build the latest release. Pushes touching `atlasopenmagic/**` also trigger a
build as a smoke test.

Locally:

```bash
./make_tarball.sh [ATLASOPENMAGIC_VERSION]
```

Every interpreter listed in `PYTHON_VERSIONS` (default: 3.10 through 3.14)
must be available on `PATH` as `pythonX.Y`; missing ones are skipped with a
warning. The result is `atlasopenmagic-<version>.tar.gz` with layout:

```
bin/                          # console scripts, rewritten to $ATLASOPENMAGIC_PYTHONBIN
lib/pythonX.Y/site-packages/  # one per built interpreter
setup-minimal.sh              # source from a shell
setup_notebook.py             # import from a notebook
VERSION
```

### Publishing

On the CVMFS stratum-0:

```bash
./utils/atlasopenmagic-cvmfs-updater.sh [-f|--force] <GITHUB_TOKEN> <ARTIFACT_ID> [VERSION]
```

If `VERSION` is omitted it is derived from the tarball inside the artifact.
The tarball is unpacked to `/cvmfs/sw.escape.eu/atlasopenmagic/<version>/` and
the `atlasopenmagic/latest` symlink is updated to point at it.

### Using

```bash
source /cvmfs/sw.escape.eu/atlasopenmagic/latest/setup-minimal.sh
```

or from a notebook:

```python
import sys
sys.path.insert(0, '/cvmfs/sw.escape.eu/atlasopenmagic/latest')
from setup_notebook import setup_atlasopenmagic
setup_atlasopenmagic()
```
