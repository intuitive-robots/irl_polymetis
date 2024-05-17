#!/usr/bin/bash -l
# More safety, by turning some bugs into errors.
set -o errexit -o pipefail -o noclobber

# ignore errexit with `&& true`
getopt --test > /dev/null && true
if [[ $? -ne 4 ]]; then
    echo 'I’m sorry, `getopt --test` failed in this environment.'
    exit 1
fi

# option --output/-o requires 1 argument
LONGOPTS=pc-ip:,port:,conda:
OPTIONS=i:p:c:

# -temporarily store output to be able to check for errors
# -activate quoting/enhanced mode (e.g. by writing out “--options”)
# -pass arguments only via   -- "$@"   to separate them correctly
# -if getopt fails, it complains itself to stdout
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@") || exit 2
# read getopt’s output this way to handle the quoting right:
eval set -- "$PARSED"

pc_ip=""
port=""
conda_env="poly"
# now enjoy the options in order and nicely split until we see --
while true; do
    case "$1" in
        -i|--pc-ip)
            pc_ip="$2"
            shift 2
            ;;
        -p|--port)
            port="$2"
            shift 2
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
args="launch_gripper.py gripper.executable_cfg.robot_ip=10.10.10.$1"
if ! [ -z "$pc_ip" ]; then
    args="$args ip=$pc_ip"
fi
if ! [ -z "$port" ]; then
    args="$args port=$port"
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
