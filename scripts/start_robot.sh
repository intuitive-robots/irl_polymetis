#!/usr/bin/bash -l
# More safety, by turning some bugs into errors.
set -o errexit -o pipefail -o noclobber

# ignore errexit with `&& true`
getopt --test > /dev/null && true
if [[ $? -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

usage="
Usage:            $(basename $0) {ROBOT_ID} [-h] [-i IP] [-p PORT] [-c CONDA_ENV] [-r]

Options:
  ROBOT_ID        The robots id (eg. 101).
  -h, --help      Display this help message.
  -i, --pc-ip     Change the ip address, where the server is running. Default is localhost.
  -p, --port      Change the port of the server. Default is 50051.
  -c, --conda     Change the conda environment, where polymetis is installed. Default is poly.
  -r, --readonly  Starts the server in readonly mode. For usage with the robots white mode.
"

# option --output/-o requires 1 argument
LONGOPTS=help,pc-ip:,port:,readonly,conda:
OPTIONS=hi:p:rc:

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

pc_ip=""
port=""
readonly=""
conda_env="poly"
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -h|--help)
            echo "$usage"
            exit 0
            ;;
        -i|--pc-ip)
            pc_ip="$2"
            shift 2
            ;;
        -p|--port)
            port="$2"
            shift 2
            ;;
        -r|--readonly)
            readonly=TRUE
            shift
            ;;
        -c|--conda)
            conda_env="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Programming error"
            exit 3
            ;;
    esac
done

# handle non-option arguments
if [[ $# -ne 1 ]]; then
    echo "$0: A robot id is required."
    exit 4
fi

# Construct launch command
args="launch_robot.py robot_client.executable_cfg.robot_ip=10.10.10.$1"
if ! [ -z "$pc_ip" ]; then
    args="$args ip=$pc_ip"
fi
if ! [ -z "$port" ]; then
    args="$args port=$port"
fi
if ! [ -z "$readonly" ]; then
    args="$args robot_client.executable_cfg.readonly=true"
fi

# Activate conda env
if [[ "$CONDA_DEFAULT_ENV" != "$conda_env" ]]; then
    echo Activating conda environment "$conda_env".
    eval "$(conda shell.bash hook)"
    conda activate "$conda_env"

    if [[ "$CONDA_DEFAULT_ENV" != "$conda_env" ]]; then
        echo Failed to activate conda environment.
        exit 1
    fi
fi

echo Adding conda environment libraries to LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib/:$LD_LIBRARY_PATH
eval "$args"
