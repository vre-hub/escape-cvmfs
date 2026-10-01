#!----------------------------------------------------------------------------
#!
#! setup-tutorial.sh
#!
#! Set up the RBAC rucio-clients for the Rucio tutorial (rbac-test instance).
#!
#! Usage (bash or zsh):
#!     source /cvmfs/sw.escape.eu/rucio/<version>-rbac/setup-tutorial.sh [<rucio account>]
#!
#! The account is taken from the first argument, else from RUCIO_ACCOUNT,
#! else setup.sh asks for it.
#!
#!----------------------------------------------------------------------------

if [ -n "$ZSH_VERSION" ]; then
    export RUCIO_HOME="$( cd "$( dirname "${(%):-%x}" )" && pwd )"
else
    export RUCIO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

if [ -n "$1" ]; then
    export RUCIO_ACCOUNT="$1"
fi

export RUCIO_CONFIG="$RUCIO_HOME/etc/rucio.cfg"
export RUCIO_AUTH_TYPE="oidc"
export RUCIO_PYTHONBIN="${RUCIO_PYTHONBIN:-python3}"
# Trusts both the Rucio servers (public CA) and EOS (CERN Grid CA).
export X509_CERT_DIR="$RUCIO_HOME/etc/certificates"

source "$RUCIO_HOME/setup.sh" --quiet || return $?

echo "Rucio $(cat "$RUCIO_HOME/FORK_COMMIT" 2>/dev/null) ready for account '$RUCIO_ACCOUNT'."
echo "Next step: run 'rucio whoami' and follow the login link."
