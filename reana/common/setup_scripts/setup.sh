#!----------------------------------------------------------------------------
#!
#! setup.sh
#!
#! setup reana-client
#!
#! Usage:
#!     source setup.sh [ --quiet | -q ]
#!
#! Requirements:
#!   1.  python version >= 3.9
#!   2.  env variable REANA_HOME must exist
#!
#! History:
#!   19Apr26: G. Guerrieri: First version
#!
#!----------------------------------------------------------------------------

# get shell type so that this can handle sh, bash and zsh
donkey_tmpVal=`\ps -o command= $$ 2>/dev/null | \cut -f 1 -d " "`
donkey_shell=`\echo $donkey_tmpVal | \sed 's/-//g'`
\echo $donkey_tmpVal | \grep -e bash > /dev/null
if [ $? -eq 0 ]; then
    donkey_shell="bash"
else
    \echo $donkey_tmpVal | \grep -e zsh > /dev/null
    if [ $? -eq 0 ]; then
        donkey_shell="zsh"
    else
        \echo $donkey_tmpVal | \grep -e "^sh$" -e "/sh$" > /dev/null
        if [ $? -eq 0 ]; then
            sh --version | \grep -e bash > /dev/null
            if [ $? -eq 0 ]; then
                donkey_shell="bash"
            fi
        fi
    fi
fi

let donkey_deb=1
if [ "$#" -eq 1 ]; then
    if [ $1 = "--quiet" -o $argv[1] = "-q" ]; then
        let donkey_deb=0
    fi
fi

if [ -z $REANA_HOME ]; then
    if [ "$donkey_shell" = "zsh" ]; then
        export REANA_HOME="$( cd "$( dirname "$0" )" && pwd )"
    else
        export REANA_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    fi
    if [ $donkey_deb -gt 0 ]; then
        \echo "INFO: \t REANA_HOME env is not set. Setting it to $REANA_HOME"
    fi
fi

# allow for switching between python and python3
if [ -z $REANA_PYTHONBIN ]; then
    export REANA_PYTHONBIN="python3"
fi
which $REANA_PYTHONBIN >/dev/null 2>&1
if [ $? -ne 0 ]; then
    if [ "$REANA_PYTHONBIN" = "python3" ]; then
        # python3 not found but python points to python 3.X so use it !
        donkey_tmpVal=`python -V 2>&1 | \awk '{print $2}' | \cut -d "." -f 1`
        if [ "$donkey_tmpVal" = "3" ]; then
            export REANA_PYTHONBIN="python"
        else
            \echo "ERROR: \t python version 3 is unavailable"
            return 64
        fi
    else
        \echo "ERROR: \t $REANA_PYTHONBIN is not found in PATH"
        return 64
    fi
fi

donkey_tmpVal=$(command -v "$REANA_PYTHONBIN")
if [[ $? -eq 0 ]] && [[ -e "$donkey_tmpVal" ]]; then
    REANA_PYTHONBINPATH=$(which "$REANA_PYTHONBIN")
    export REANA_PYTHONBINPATH=$(readlink -f "$REANA_PYTHONBINPATH")
else
    echo "ERROR: $REANA_PYTHONBIN does not seem to exist as a file; unable to use as interpreter"
    exit 64
fi


donkey_thisPythonVersion=`$REANA_PYTHONBIN -V 2>&1 | \awk '{print $2}'`
donkey_thisPythonVersionMajor=`\echo $donkey_thisPythonVersion | \cut -d "." -f 1`
donkey_thisPythonVersionMinor=`\echo $donkey_thisPythonVersion | \cut -d "." -f 2`
let thisPythonVersionInt=`expr $donkey_thisPythonVersionMajor \* 10000 + $donkey_thisPythonVersionMinor \* 100`
# need python >= 3.9
if [[ $thisPythonVersionInt -lt 30900 ]]; then
    \echo "ERROR: \t Your python version is $donkey_thisPythonVersion; we need 3.9 or newer."
    return 64
fi
donkey_thisPyVer=`\echo $donkey_thisPythonVersion | \cut -d "." -f 1-2`

# os version
donkey_glv="`getconf GNU_LIBC_VERSION 2>&1 | \awk '{print $NF}' | \awk -F. '{printf "%d%02d", $1, $2}'`"
if [ $donkey_glv -le 205 ]; then
    donkey_slcVer="slc5"
    \echo "ERROR: \t $donkey_slcVer detected.  This is no longer supported."
    return 64
elif [ $donkey_glv -le 216 ]; then
    donkey_slcVer="slc6"
elif [ $donkey_glv -le 227 ]; then
    donkey_slcVer="centos7"
elif [ $donkey_glv -le 233 ]; then
    donkey_slcVer="centos8s"
else
    donkey_slcVer="el9"
fi
if [ $donkey_deb -gt 0 ]; then
    \echo "INFO: \t  Setting compatibility to $donkey_slcVer"
fi

# get reana python path
donkey_reanaPyPath=`\find $REANA_HOME/lib -mindepth 2 -maxdepth 2 -name site-packages | \grep -e python$donkey_thisPyVer`
if [ "$donkey_reanaPyPath" = "" ]; then
    donkey_reanaPyPath=`\find $REANA_HOME/lib -mindepth 2 -maxdepth 2 -name site-packages | \grep -e "python$donkey_thisPythonVersionMajor" | \tail -n 1`
    if [ "$donkey_reanaPyPath" = "" ]; then
        \echo "ERROR: \t  Unable to determine reana python path"
        return 64
    fi
fi

# all ok now, start setting up ...

export PATH="$REANA_HOME/bin:$PATH"
export PYTHONPATH="${donkey_reanaPyPath}:${PYTHONPATH}"

if [ "$donkey_shell" = "bash" ]; then
    eval "$(register-python-argcomplete reana-client)"
fi

if [[ -z $REANA_SERVER_URL ]]; then
    if [ $donkey_deb -gt 0 ]; then
        \echo "INFO: \t  REANA_SERVER_URL is not set. Please export it before running reana-client, e.g.:"
        \echo "INFO: \t    export REANA_SERVER_URL=https://reana.cern.ch"
    fi
fi

if [[ -z $REANA_ACCESS_TOKEN ]]; then
    if [ $donkey_deb -gt 0 ]; then
        \echo "INFO: \t  REANA_ACCESS_TOKEN is not set. Please export it before running reana-client."
    fi
fi

unset donkey_tmpVal donkey_shell donkey_deb donkey_glv donkey_slcVer donkey_thisPythonVersion thisPythonVersionInt donkey_thisPyVer donkey_thisPythonVersionMajor donkey_thisPythonVersionMinor donkey_reanaPyPath

return 0
