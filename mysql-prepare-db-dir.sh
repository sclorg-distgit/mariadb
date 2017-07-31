#!/bin/sh

# This script creates the mysql data directory during first service start.
# In subsequent starts, it does nothing much.

source "`dirname ${BASH_SOURCE[0]}`/mysql-scripts-common"

# If two args given first is user, second is group
# otherwise the arg is the systemd service file
if [ "$#" -eq 2 ]
then
    myuser="$1"
    mygroup="$2"
else
    # Absorb configuration settings from the specified systemd service file,
    # or the default service if not specified
    SERVICE_NAME="$1"
    if [ x"$SERVICE_NAME" = x ]
    then
        SERVICE_NAME=@DAEMON_NAME@.service
    fi

    myuser=`systemctl show -p User "${SERVICE_NAME}" |
      sed 's/^User=//'`
    if [ x"$myuser" = x ]
    then
        myuser=mysql
    fi

    mygroup=`systemctl show -p Group "${SERVICE_NAME}" |
      sed 's/^Group=//'`
    if [ x"$mygroup" = x ]
    then
        mygroup=mysql
    fi
fi

# Set up the errlogfile with appropriate permissions
if [ ! -e "$errlogfile" -a ! -h "$errlogfile" -a x$(dirname "$errlogfile") = "x/var/log" ]; then
    case $(basename "$errlogfile") in
        mysql*.log|mariadb*.log) install /dev/null -m0640 -o$myuser -g$mygroup "$errlogfile" ;;
        *) ;;
    esac
else
    # Provide some advice if the log file cannot be created by this script
    errlogdir=$(dirname "$errlogfile")
    if ! [ -d "$errlogdir" ] ; then
        echo "The directory $errlogdir does not exist."
        exit 1
    elif [ -e "$errlogfile" -a ! -w "$errlogfile" ] ; then
        echo "The log file $errlogfile cannot be written, please, fix its permissions."
        echo "The daemon will be run under $myuser:$mygroup"
        exit 1
    fi
fi



export LC_ALL=C

# Returns content of the specified directory
# If listing files fails, fake-file is returned so which means
# we'll behave like there was some data initialized
# Some files or directories are fine to be there, so those are
# explicitly removed from the listing
# @param <dir> datadir
list_datadir ()
{
    ( ls -1A "$1" 2>/dev/null || echo "fake-file" ) | grep -v \
    -e '^lost+found$' \
    -e '\.err$' \
    -e '^\.bash_history$'
}

# Checks whether datadir should be initialized
# @param <dir> datadir
should_initialize ()
{
    test -z "$(list_datadir "$1")"
}

# Make the data directory if doesn't exist or empty
if should_initialize "$datadir" ; then

    # Now create the database
    echo "Initializing @NICE_PROJECT_NAME@ database"
    @bindir@/mysql_install_db --rpm --datadir="$datadir" --user="$myuser"
    ret=$?
    if [ $ret -ne 0 ] ; then
        echo "Initialization of @NICE_PROJECT_NAME@ database failed." >&2
        echo "Perhaps @sysconfdir@/my.cnf is misconfigured." >&2
        echo "Note, that you may need to clean up any partially-created database files in $datadir" >&2
        exit $ret
    fi
    # upgrade does not need to be run on a fresh datadir
    echo "@VERSION@-MariaDB" >"$datadir/mysql_upgrade_info"
else
    if [ -d "$datadir/mysql/" ] ; then
        # mysql dir exists, it seems data are initialized properly
        echo "Database @NICE_PROJECT_NAME@ is probably initialized in $datadir already, nothing is done."
        echo "If this is not the case, make sure the $datadir is empty before running `basename $0`."
    else
        # if the directory is not empty but mysql/ directory is missing, then
        # print error and let user to initialize manually or empty the directory
        echo "Database @NICE_PROJECT_NAME@ is not initialized, but the directory $datadir is not empty, so initialization cannot be done."
        echo "Make sure the $datadir is empty before running `basename $0`."
        exit 1
    fi
fi

exit 0
