# Yuki on CVMFS

This directory packages Yuki, Celebi, Erlang, and RabbitMQ as an immutable
Python 3.11 runtime for CVMFS. Storage, workflow state, SSH keys, RabbitMQ data,
logs, and PID files remain under the user's writable `~/.Yuki` directory.

## Build

Build from local Yuki and matching Celebi source checkouts:

```bash
YUKI_SOURCE_DIR=/path/to/Yuki \
CELEBI_SOURCE_DIR=/path/to/Celebi \
./make_tarball.sh
```

The build requires Conda (or Mamba) and `conda-pack`. Set `RABBITMQ_VERSION`
to request a specific conda-forge version; otherwise the current version is
selected and recorded in `RABBITMQ_PACKAGES`.

The output is `yuki-<version>-<commit>.tar.gz` plus a SHA-256 checksum.

The deployed layout is:

```text
/cvmfs/sw.escape.eu/yuki/<version>/
├── bin/
│   ├── yuki
│   ├── yuki-service
│   ├── rabbitmq-server
│   └── rabbitmqctl
├── lib/
│   ├── python3.11/site-packages/
│   ├── rabbitmq/                 # packed Erlang + RabbitMQ environment
│   └── erlang -> rabbitmq/lib/erlang
└── setup.sh
```

## Deploy

```bash
./utils/yuki-cvmfs-updater.sh <GITHUB_TOKEN> <ARTIFACT_ID>
```

## Use

```bash
source /cvmfs/sw.escape.eu/yuki/latest/setup.sh
yuki-service start
```

Lifecycle commands are:

```bash
yuki-service status
yuki-service logs
yuki-service stop
yuki-service restart
```

`yuki-service start` creates the writable directory structure, starts the
bundled RabbitMQ, waits for port 5672, starts the Yuki Flask/Celery processes,
and waits for port 3315. If RabbitMQ is already running on the configured port,
the service uses it and will not stop it later.

Runtime state is created automatically:

```text
~/.Yuki/
├── RabbitMQ/{mnesia,log,rabbitmq.pid}
├── Storage/
├── Workflows/
├── logs/
└── run/
```

The default state directory is `~/.Yuki`. A dedicated service account can set
`HOME=/srv/yuki`; note that parts of Yuki still use `$HOME/.Yuki` directly, so
custom `YUKIDIR` values should match that location.
