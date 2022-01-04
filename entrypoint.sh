#!/bin/bash

DIR0="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

BUILD_OPTS="--build"

sleeping () {
    echo "Sleeping due to an issue..."
    sleep infinity
}

if [ -f "$DIR0/.env" ]; then
    export $(cat $DIR0/.env | xargs)
fi

if [ -z "$1" ]; then
    BUILD_OPTS=""
fi

if [ -z "$PARALLEL" ]; then
    PARALLEL=0
fi

if [ -z "$REPEAT" ]; then
    REPEAT=0
fi

if [ "$PARALLEL" == "1" ]; then
    if [ ! -d "$SRC_DIR" ]; then
        echo "SRC_DIR not found: $SRC_DIR"
        sleeping
    fi
    if [ ! -d "$DEST_DIR" ]; then
        echo "DEST_DIR not found: $DEST_DIR"
        sleeping
    fi
    if ! [ -x "$(command -v pigz)" ]; then
        echo 'Installing pigz.'
        apt-get install -y pigz
    fi
    PROCS=$(nproc)
    BASENAME=$(basename $SRC_DIR | cut -d "." -f 1)
    DIRNAME=$(dirname $SRC_DIR)
    # replace all "/" with "_"
    DIRNAME=$(echo $DIRNAME | sed 's/\//_/g')
    DIRNAME="${DIRNAME:1}"
    FNAME="$DEST_DIR/${DIRNAME}_${BASENAME}.tar.gz"
    tar --use-compress-program="pigz -9 -k -p$PROCS " -cvf $FNAME $SRC_DIR
    ls -la $FNAME
    echo "Done, sleeping now."
    sleep infinity
fi

VENV_DIR=$(ls $DIR0/venv*/bin/activate | head -n 1)

cat $DIR0/scripts/get-pip.txt > $DIR0/scripts/get-pip.py

MAKEVENV=$DIR0/makevenv.sh
if [ ! -f "$VENV_DIR" ]; then
    echo "No virtualenv found. Creating one..."
    if [ ! -f "$MAKEVENV" ]; then
        echo "No makevenv.sh found. Exiting..."
        sleeping
    fi
    $MAKEVENV
    VENV_DIR=$(ls $DIR0/venv*/bin/activate | head -n 1)
fi

if [ ! -f "$VENV_DIR" ]; then
    echo "No Virtual Env ($VENV_DIR) found. Exiting..."
    sleeping
fi
. $VENV_DIR

PY=$(which python3.9)

if [ ! -f "$PY" ]; then
    echo "No python3.9 found. Exiting..."
    sleeping
fi

HOST_ETC=$(ls /host_etc)

if [ -z "$HOST_ETC" ]; then
    echo "No /host_etc found. Exiting..."
    sleeping
fi

HOSTNAME=$(cat /host_etc/hostname)

if [ -z "$HOSTNAME" ]; then
    echo "No hostname found. Exiting..."
    sleeping
fi

IS_UBUNTU=$(cat /etc/os-release | grep ubuntu)

if [ -z "$IS_UBUNTU" ]; then
    AWSCLI_INSTALLER=$DIR0/aws-cli-installer.sh

    if [ ! -f "$AWSCLI_INSTALLER" ]; then
        echo "No aws-cli-installer.sh found. Exiting..."
        sleeping
    fi

    $AWSCLI_INSTALLER
else
    apt install awscli -y
fi

PYCACHE=$DIR0/__pycache__

if [ -d "$PYCACHE" ]; then
    echo "Moving pycache contents..."
    mv $PYCACHE/* $DIR0/
    mv $DIR0/relocate_pyc.cpython-39.pyc $DIR0/relocate_pyc.pyc
    rm -rf $PYCACHE
fi

##################################################
MOVER=$DIR0/relocate_pyc.pyc

if [ ! -f "$MOVER" ]; then
    echo "No mover found. Exiting..."
    sleeping
fi

VENV_DIR=$(dirname $VENV_DIR)
VENV_DIR=$(dirname $VENV_DIR)
$PY $MOVER $DIR0 $VENV_DIR
##################################################

APP=$DIR0/tarbaby.py

if [ ! -f "$APP" ]; then
    APP=$DIR0/tarbaby.pyc
fi

if [ ! -f "$APP" ]; then
    echo "No tarbaby.py found. Exiting..."
    sleeping
fi

if [ -z "$BUILD_OPTS" ]; then
    echo "Running $PY $APP $HOSTNAME"
    $PY $APP $HOSTNAME
fi
