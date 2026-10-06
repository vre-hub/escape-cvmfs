#!----------------------------------------------------------------------------
#!
#! setup-tutorial.sh
#!
#! Environment for the RBAC rucio-clients on CVMFS. It is the CVMFS copy of the
#! container image hdemule/rucio-clients-rbac (same client, same rucio.cfg,
#! same CA bundle). See FORK_COMMIT for the exact build.
#!
#! Usage (bash or zsh):
#!     source /cvmfs/sw.escape.eu/rucio/<version>/setup-tutorial.sh [<rucio account>]
#!
#! The account is optional. Without it, the server uses the default account of
#! your identity. Change it later with:  set-username [<account>]
#!
#!----------------------------------------------------------------------------

if [ -n "$ZSH_VERSION" ]; then
    export RUCIO_HOME="$( cd "$( dirname "${(%):-%x}" )" && pwd )"
else
    export RUCIO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

export RUCIO_CONFIG="$RUCIO_HOME/etc/rucio.cfg"
export RUCIO_AUTH_TYPE="oidc"
export RUCIO_PYTHONBIN="${RUCIO_PYTHONBIN:-python3}"
# One CA directory for the Rucio servers and for EOS. It is made from etc/tls-ca-bundle.pem.
# The client uses X509_CERT_DIR before the ca_cert setting of rucio.cfg.
export X509_CERT_DIR="$RUCIO_HOME/etc/certificates"

if [ -n "$1" ]; then
    export RUCIO_ACCOUNT="$1"
fi

# setup.sh asks for an account when RUCIO_ACCOUNT is empty. Give it a dummy value, then remove it.
donkey_dummy_account=""
if [ -z "$RUCIO_ACCOUNT" ]; then
    export RUCIO_ACCOUNT="default-account"
    donkey_dummy_account=1
fi

source "$RUCIO_HOME/setup.sh" --quiet || return $?

if [ -n "$donkey_dummy_account" ]; then
    unset RUCIO_ACCOUNT
fi
unset donkey_dummy_account

# Same as the command /usr/local/bin/set-username in the container image.
# The config on CVMFS is read-only, so this sets the environment variable RUCIO_ACCOUNT.
set-username () {
    local account
    if [ $# -gt 0 ]; then
        account="$1"
    else
        printf "Rucio account (leave empty to use your identity's default): "
        read -r account
    fi
    if [ -n "$account" ]; then
        export RUCIO_ACCOUNT="$account"
        echo "Account set to '$account'"
    else
        unset RUCIO_ACCOUNT
        echo "Account removed; your identity's default account will be used"
    fi
    # The cached token belongs to the previous account, so force a new login.
    # The path comes from the config (auth_token_file_path), as in the container image.
    local token_file
    token_file="$(sed -n 's/^auth_token_file_path[[:space:]]*=[[:space:]]*//p' "${RUCIO_CONFIG:-$RUCIO_HOME/etc/rucio.cfg}")"
    if [ -n "$token_file" ]; then
        rm -f "$token_file"
    fi
}

echo "Rucio $(cat "$RUCIO_HOME/FORK_COMMIT" 2>/dev/null | head -1) ready${RUCIO_ACCOUNT:+ for account '$RUCIO_ACCOUNT'}."
echo "Next step: run 'rucio whoami' and follow the login link."
