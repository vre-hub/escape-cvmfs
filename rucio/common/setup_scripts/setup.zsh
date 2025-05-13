export RUCIO_HOME="$( cd "$( dirname "$0}" )" && pwd )"
source $RUCIO_HOME/setup.sh $@
return $?
