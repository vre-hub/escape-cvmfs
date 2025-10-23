import os
import json

def write_jupyterlab_config():
    dir_config_jupyterlab = os.getenv('JUPYTER_CONFIG_DIR', os.path.join(os.getenv('HOME'), '.jupyter'))
    file_server_config = os.path.join(dir_config_jupyterlab, 'jupyter_server_config.json')

    if not os.path.exists(dir_config_jupyterlab):
        os.makedirs(dir_config_jupyterlab, exist_ok=True)
    elif os.path.isfile(file_server_config):
        with open(file_server_config, "r") as config_file:
            config_payload = config_file.read()
    else:
        config_payload = "{}"

    try:
        config_json = json.loads(config_payload)
    except:
        config_json = {}

    # Base configurations for all instances
    escape_config = {
        "name": os.getenv('RUCIO_NAME', 'vre-rucio.cern.ch'),
        "display_name": os.getenv('RUCIO_DISPLAY_NAME', 'ESCAPE Rucio instance'),
        "rucio_base_url": os.getenv('RUCIO_BASE_URL', 'https://vre-rucio.cern.ch'),
        "rucio_auth_url": os.getenv('RUCIO_AUTH_URL', 'https://vre-rucio-auth.cern.ch'),
        "rucio_webui_url": os.getenv('RUCIO_WEBUI_URL', 'https://vre-rucio-ui.cern.ch'),
        "rucio_ca_cert": os.getenv('RUCIO_CA_CERT', '/eos/user/e/engarcia/rucio_ca_certs/rucio_ca.pem'),
        "site_name": os.getenv('RUCIO_SITE_NAME', 'CERN'),
        "vo": os.getenv('RUCIO_VO', 'escape'),
        "voms_enabled": os.getenv('RUCIO_VOMS_ENABLED', '0') == '1',
        "voms_vomses_path": os.getenv('RUCIO_VOMS_VOMSES_PATH', '/etc/vomses'),
        "voms_certdir_path": os.getenv('RUCIO_VOMS_CERTDIR_PATH', '/etc/grid-security/vomsdir'),
        "voms_vomsdir_path": os.getenv('RUCIO_VOMS_VOMSDIR_PATH', '/etc/grid-security/vomsdir'),
        "destination_rse": os.getenv('RUCIO_DESTINATION_RSE', 'CERN-EOSPILOT'),
        "rse_mount_path": os.getenv('RUCIO_RSE_MOUNT_PATH', '/eos/eulake'),
        "replication_rule_lifetime_days": int(os.getenv('RUCIO_REPLICATION_RULE_LIFETIME_DAYS')) if os.getenv('RUCIO_REPLICATION_RULE_LIFETIME_DAYS') else 1,
        "path_begins_at": int(os.getenv('RUCIO_PATH_BEGINS_AT', '5')),
        "mode": os.getenv('RUCIO_MODE', 'replica'),
        "wildcard_enabled": os.getenv('RUCIO_WILDCARD_ENABLED', '1') == '1',
        #"oidc_auth": os.getenv('RUCIO_OIDC_AUTH'),
        #"oidc_env_name": os.getenv('RUCIO_OIDC_ENV_NAME'),
        #"oidc_file_name": os.getenv('RUCIO_OIDC_FILE_NAME'),
    }
    atlas_config = {
        "name": os.getenv('ATLAS_RUCIO_NAME', 'https://voatlasrucio-server-prod.cern.ch'),
        "display_name": os.getenv('ATLAS_RUCIO_DISPLAY_NAME', 'ATLAS RUCIO'),
        "rucio_base_url": os.getenv('ATLAS_RUCIO_BASE_URL', 'https://voatlasrucio-server-prod.cern.ch:443'),
        "rucio_auth_url": os.getenv('ATLAS_RUCIO_AUTH_URL', 'https://atlas-rucio-auth.cern.ch:443'),
        "rucio_webui_url": os.getenv('ATLAS_RUCIO_WEBUI_URL', 'https://rucio-ui.cern.ch'),
        "rucio_ca_cert": os.getenv('RUCIO_CA_CERT', '/eos/user/e/engarcia/rucio_ca_certs/rucio_ca.pem'),
        "site_name": os.getenv('ATLAS_RUCIO_SITE_NAME', 'CERN'),
        "vo": os.getenv('ATLAS_RUCIO_VO', 'atlas'),
        "voms_enabled": os.getenv('RUCIO_VOMS_ENABLED', '0') == '1',
        "voms_vomses_path": os.getenv('RUCIO_VOMS_VOMSES_PATH', '/etc/vomses'),
        "voms_certdir_path": os.getenv('RUCIO_VOMS_CERTDIR_PATH', '/etc/grid-security/vomsdir'),
        "voms_vomsdir_path": os.getenv('RUCIO_VOMS_VOMSDIR_PATH', '/etc/grid-security/vomsdir'),
        "destination_rse": os.getenv('ATLAS_RUCIO_DESTINATION_RSE', 'CERN-PROD_PHYS-TOP'),
        "rse_mount_path": os.getenv('ATLAS_RUCIO_RSE_MOUNT_PATH', '/eos/atlas/atlasgroupdisk/phys-top'),
        "replication_rule_lifetime_days": int(os.getenv('ATLAS_RUCIO_REPLICATION_RULE_LIFETIME_DAYS')) if os.getenv('ATLAS_RUCIO_REPLICATION_RULE_LIFETIME_DAYS') else 1,
        "path_begins_at": int(os.getenv('ATLAS_RUCIO_PATH_BEGINS_AT', '4')),
        "mode": os.getenv('ATLAS_RUCIO_MODE', 'replica'),
        "wildcard_enabled": os.getenv('ATLAS_RUCIO_WILDCARD_ENABLED', '1') == '1',
    }
    fcc_config = {
        "name": os.getenv('FCC_RUCIO_NAME', 'fcc.rucioit.cern.ch'),
        "display_name": os.getenv('FCC_RUCIO_DISPLAY_NAME', 'FCC RUCIO'),
        "rucio_base_url": os.getenv('FCC_RUCIO_BASE_URL', 'https://fcc-server.rucioit.cern.ch'),
        "rucio_auth_url": os.getenv('FCC_RUCIO_AUTH_URL', 'https://fcc-auth.rucioit.cern.ch'),
        "rucio_webui_url": os.getenv('FCC_RUCIO_WEBUI_URL', 'https://fcc-webui.rucioit.cern.ch'),
        "rucio_ca_cert": "/cvmfs/sw.escape.eu/etc/ssl/certs/tls-ca-bundle.pem",
        "site_name": os.getenv('FCC_RUCIO_SITE_NAME', 'CERN'),
        "vo": os.getenv('FCC_RUCIO_VO', 'fcc'),
        "voms_enabled": os.getenv('RUCIO_VOMS_ENABLED', '0') == '1',
        "voms_vomses_path": os.getenv('RUCIO_VOMS_VOMSES_PATH', '/etc/vomses'),
        "voms_certdir_path": os.getenv('RUCIO_VOMS_CERTDIR_PATH', '/etc/grid-security/vomsdir'),
        "voms_vomsdir_path": os.getenv('RUCIO_VOMS_VOMSDIR_PATH', '/etc/grid-security/vomsdir'),
        "destination_rse": os.getenv('FCC_RUCIO_DESTINATION_RSE', 'FCC_PROD_PHYS_TOP'),
        "rse_mount_path": os.getenv('FCC_RUCIO_RSE_MOUNT_PATH', '/eos/workspace/r/rucioit/FCC_PROD_PHYS_TOP'),
        "replication_rule_lifetime_days": int(os.getenv('FCC_RUCIO_REPLICATION_RULE_LIFETIME_DAYS')) if os.getenv('FCC_RUCIO_REPLICATION_RULE_LIFETIME_DAYS') else 1,
        "path_begins_at": int(os.getenv('FCC_RUCIO_PATH_BEGINS_AT', '5')),
        "mode": os.getenv('FCC_RUCIO_MODE', 'replica'),
        "wildcard_enabled": os.getenv('FCC_RUCIO_WILDCARD_ENABLED', '1') == '1',
    }

    # Map configs for dynamic update
    configs = { "escape": escape_config, "atlas": atlas_config, "fcc": fcc_config }

    # Read SWAN environment variables
    swan_instance = os.getenv('SWAN_RUCIO_INSTANCE', '').lower()
    swan_rse = os.getenv('SWAN_RUCIO_RSE')
    swan_rse_path = os.getenv('SWAN_RUCIO_RSE_PATH')
    swan_path_number = os.getenv('SWAN_RUCIO_RSE_PATH_BEGINS_AT')

    # Apply overrides to selected instance
    if swan_instance in configs:
        cfg = configs[swan_instance]
        if swan_rse:
            cfg['destination_rse'] = swan_rse
        if swan_rse_path:
            cfg['rse_mount_path'] = swan_rse_path
        if swan_path_number:
            cfg['path_begins_at'] = int(swan_path_number)

    config_json['RucioConfig'] = {
        'instances': [configs[swan_instance]] if swan_instance else [escape_config, atlas_config, fcc_config],
        'default_instance': configs[swan_instance]['name'] if swan_instance else escape_config['name'],
        'default_auth_type': os.getenv('RUCIO_DEFAULT_AUTH_TYPE', 'x509_proxy'),
        'log_level': os.getenv('RUCIO_LOG_LEVEL', 'debug'),
    }

    with open(file_server_config, 'w') as config_file:
        config_file.write(json.dumps(config_json, indent=2))

def write_ipython_config():
    file_path = os.path.join(os.getenv('HOME'), '.ipython/profile_default')
    file_name = os.path.join(file_path, 'ipython_kernel_config.json')
    extension_module = 'rucio_jupyterlab.kernels.ipython'

    if not os.path.isfile(file_name):
        os.makedirs(file_path, exist_ok=True)
    else:
        config_file = open(file_name, 'r')
        config_payload = config_file.read()
        config_file.close()

    try:
        config_json = json.loads(config_payload)
    except:
        config_json = {}

    if 'IPKernelApp' not in config_json:
        config_json['IPKernelApp'] = {}

    ipkernel_app = config_json['IPKernelApp']

    if 'extensions' not in ipkernel_app:
        ipkernel_app['extensions'] = []

    if extension_module not in ipkernel_app['extensions']:
        ipkernel_app['extensions'].append(extension_module)

    config_file = open(file_name, 'w')
    config_file.write(json.dumps(config_json, indent=2))
    config_file.close()

write_jupyterlab_config()
# write_ipython_config()
