#!----------------------------------------------------------------------------
#!
#! setup.sh
#!
#! setup rucio-clients 
#!
#! Usage:
#!     source rucio-clients.sh [ --quiet | -q ]
#!
#! Requirements:
#!   1.  python versions >= 2.7; no 32-bit support (rucio versions >= 1.20.8)
#!   2.  env variable RUCIO_HOME must exist
#!
#! History:
#!   13May25: G. Guerrieri: First version  
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

if [ -z $RUCIO_HOME ]; then
    if [ "$donkey_shell" = "zsh" ]; then
        export RUCIO_HOME="$( cd "$( dirname "$0}" )" && pwd )"
    else
        export RUCIO_HOME="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    fi
    if [ $donkey_deb -gt 0 ]; then
        \echo "RUCIO_HOME env is not set. Set it to $RUCIO_HOME"
    fi    
fi

# allow for switching between python and python3
if [ -z $RUCIO_PYTHONBIN ]; then
    export RUCIO_PYTHONBIN="python"
fi
which $RUCIO_PYTHONBIN >/dev/null 2>&1
if [ $? -ne 0 ]; then
    if [ "$RUCIO_PYTHONBIN" = "python3" ]; then
        # python3 not found but python points to python 3.X so use it !
        donkey_tmpVal=`python -V 2>&1 | \awk '{print $2}' | \cut -d "." -f 1`
        if [ "$donkey_tmpVal" = "3" ]; then
            export RUCIO_PYTHONBIN="python"
        else
            \echo "Error: python version 3 is unavailable"
            return 64	    
        fi	     
    else
        \echo "Error: $RUCIO_PYTHONBIN is not found in PATH"
        return 64
    fi
fi

donkey_tmpVal=`command -v $RUCIO_PYTHONBIN`
if [[ $? -eq 0 ]] && [[ -e "$donkey_tmpVal" ]]; then
    RUCIO_PYTHONBINPATH=`which $RUCIO_PYTHONBIN`
    export RUCIO_PYTHONBINPATH=`readlink -f $RUCIO_PYTHONBINPATH`
else
    \echo "ERROR: $RUCIO_PYTHONBIN does not seem to exist as a file'; unable to use as interpretor"
    return 64
fi

donkey_thisPythonVersion=`$RUCIO_PYTHONBIN -V 2>&1 | \awk '{print $2}'`
donkey_thisPythonVersionMajor=`\echo $donkey_thisPythonVersion | \cut -d "." -f 1`
donkey_thisPythonVersionMinor=`\echo $donkey_thisPythonVersion | \cut -d "." -f 2`
let thisPythonVersionInt=`expr $donkey_thisPythonVersionMajor \* 10000 + $donkey_thisPythonVersionMinor \* 100`
# need python >= 2.7 for python 2
if [[ "$donkey_thisPythonVersionMajor" = "2" ]] && [[ $thisPythonVersionInt -lt 20700 ]]; then
    \echo "Error: Your python version is $donkey_thisPythonVersion; we need 2.7 or newer."
    return 64
fi
donkey_thisPyVer=`\echo $donkey_thisPythonVersion | \cut -d "." -f 1-2`

# os version
donkey_glv="`getconf GNU_LIBC_VERSION 2>&1 | \awk '{print $NF}' | \awk -F. '{printf "%d%02d", $1, $2}'`"
if [ $donkey_glv -le 205 ]; then
    donkey_slcVer="slc5"
    \echo "Error: $donkey_slcVer detected.  This is no longer supported."
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
    \echo "Info: Setting compatibility to $donkey_slcVer"
fi

# get rucio python path
donkey_rucioPyPath=`\find $RUCIO_HOME/lib -mindepth 2 -maxdepth 2 -name site-packages | \grep -e python$donkey_thisPyVer`
if [ "$donkey_rucioPyPath" = "" ]; then
    donkey_rucioPyPath=`\find $RUCIO_HOME/lib -mindepth 2 -maxdepth 2 -name site-packages | \grep -e "python$donkey_thisPythonVersionMajor" | \tail -n 1`
    if [ "$donkey_rucioPyPath" = "" ]; then
        \echo "Error: Unable to determine rucio python path"
        return 64
    fi
fi

# all ok now, start setting up ...

export PATH="$RUCIO_HOME/bin:$PATH"
export PYTHONPATH="${donkey_rucioPyPath}:${PYTHONPATH}"

# --- Kerberos/EMI support removed from here ---

if [ "$donkey_shell" = "bash" ]; then
    eval "$(register-python-argcomplete rucio)"
    eval "$(register-python-argcomplete rucio-admin)"
fi

if [[ -z $RUCIO_AUTH_TYPE ]]; then
   export RUCIO_AUTH_TYPE="x509_proxy"
   if [ $donkey_deb -gt 0 ]; then
       \echo "Info: Set RUCIO_AUTH_TYPE to x509_proxy"
   fi
fi

if [[ -z $X509_USER_PROXY ]]; then
   export X509_USER_PROXY="/tmp/x509up_u$(id -u)"
fi

if [[ -z $RUCIO_ACCOUNT ]]; then
    donkey_account=` sh -c 'voms-proxy-info --all 2>/dev/null'| \grep -e 'attribute : nickname =' | \awk '{print $5}'`
    if [ -z "$donkey_account" ]; then
        donkey_counter=0
        while true; do
            donkey_yn=
            if [ "$donkey_shell" = "zsh" ]; then
                vared -p "Do you want to set the RUCIO_ACCOUNT to $USER (y/n)?" donkey_yn 
            else
                read -p "Do you want to set the RUCIO_ACCOUNT to $USER (y/n)?" donkey_yn
            fi
            case $donkey_yn in
                [Yy]* )  export RUCIO_ACCOUNT=$USER; \echo 'To avoid this question, you should set the environment variable RUCIO_ACCOUNT or have a valid grid proxy'; break;;
                [Nn]* )
                    if [ "$donkey_shell" = "zsh" ]; then
                        donkey_account=;  vared -p "Please enter the Rucio account you want to use: " donkey_account; export RUCIO_ACCOUNT=$donkey_account
                    else
                        read -p "Please enter the Rucio account you want to use: " donkey_account; export RUCIO_ACCOUNT=$donkey_account
                    fi;
                    break;;
                * ) \echo "Please answer yes or no.";;
            esac
            donkey_counter=`expr $donkey_counter + 1`
            if [ "$donkey_counter" -eq 3 ]; then
                if [ $donkey_deb -gt 0 ]; then
                    \echo "Info: Max. tries reached."
                fi
                export RUCIO_ACCOUNT=$USER
                break;
            fi            
        done
    else
        export RUCIO_ACCOUNT=$donkey_account
    fi
    
    if [ $donkey_deb -gt 0 ]; then
        \echo "Info: Set RUCIO_ACCOUNT to $RUCIO_ACCOUNT"
    fi
fi

unset donkey_tmpVal donkey_shell donkey_deb donkey_glv donkey_slcVer donkey_thisPythonVersion thisPythonVersionInt donkey_thisPyVer donkey_thisPythonVersionMajor donkey_thisPythonVersionMinor donkey_rucioPyPath donkey_counter donkey_account donkey_yn

return 0
