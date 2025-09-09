# Rucio JupyterLab extension `jupyter_server_config.py` file

This script creates the following files, needed to configure the Rucio JupyterLab extension.
  * `~/.jupyter/jupyter_server_config.json`
  * `~/.ipython/profile_default/ipython_kernel_config.json`

The file must be located in `/cvmfs/sw.escape.eu/etc/jupyter/jupyter_server_config.py`, see 
[swan-cern/jupyter-images#230](https://github.com/swan-cern/jupyter-images/pull/230) for more information. It is used 
during the spawning of the [SWAN session](https://github.com/swan-cern/jupyter-images/blob/main/swan/scripts/before-notebook.d/01_rucio.sh), in order to setup the Rucio extension.

## Upload and/or update the file within the sw.escape.eu cvmfs repository

1. Make sure you have ESCAPE CVMFS writing rights.
2. Clone this repository and go to the `/etc/jupyter` directory.
3. Either update the script manually or run the `jupyter_server_config-updater.sh` script.
