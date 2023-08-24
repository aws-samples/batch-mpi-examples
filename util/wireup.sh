#!/bin/bash

# This handles MPI wireup operations in AWS Batch MNP jobs.
# For more details, run `wireup.sh help`
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

function usage() {
    cat <<EOF

wireup is a script to handle multi-node coordination in AWS Batch for e.g., MPI

Usage: wireup <command> [<options>...]

Author: J. Lowell Wofford <jlowellw@amazon.com>

commands:
    help|usage
        Print this usage information and exit.
    install
        The install command sets up SSH configuration and keys.
        This is intended to be used, e.g., inside of a Dockerfile like this:
        ...
        COPY wireup.sh /wireup
        RUN chmod +x /wireup
        &&  wireup install
        ...
    run <cmd> [<args>...]
        Executes the primary wireup function.  This behaves differently depending
        on whether the node is a main or child node.

        main node: 
            1. Start an SSHD that children can SSH to
            2. Listen on a named pipe for host/ip reports from children
            3. Wait until all children have reported in
            4. Create hostfiles:
                - /hostfile -- one host on each line
                - /hostfile-intel -- Intel-formatted hostfile (e.g. <host>:<slots>)
                - /hostfile-ompi -- OpenMPI-formatted hostfile (e.g. <host> slots=<slots>)
            5. Execute the <cmd> specified.  
               This is usually going to be something like: mpirun -f /hostfile [opts] <cmd>...
            6. Once the primary command completes, tell children to gracefully exit.
        child node:
            1. Start an SSHD that other nodes can SSH to
            2. SSH to the main node and report our host/slots
            3. Wait indefinitely, but gracefully exit if we receive SIGUSR1
    report <host> <slots>
        This is executed by children on the main node (via SSH) to report host/slots.
    stop
        This sends SIGUSR1 to the PID stored in the pid file to trigger a graceful exit.
        This is used by the main node to stop children.

configuration:
    Several environment variables control wireup execution.
    WIREUP_BASE=<dir>
        working/install directory for wireup (default: /opt/wireup)
    WIREUP_SSHD_PORT=<num> 
        port for SSHD to listen on (default: 2222)
    WIREUP_TIMEOUT=<seconds> 
        how long to wait for children to report before failing (default: 600)
    WIREUP_SSH_POLLING_INTERVAL 
        how long children should wait before retrying their report (default: 5)
    WIREUP_COMM_PIPE 
        location of the communcations pipe (default: $WIREUP_BASE/pipe)
    WIREUP_HOSTFILE
        location to create the hostfile (default: /hostfile)
        note: specialized hostfiles are built off of this, e.g., /hostfile-intel
    WIREUP_IFACE_NAME
        name of network interface (default: eth0)
    WIREUP_DATEFMT
        date format string to use when logging (default: %d/%m/%Y %H:%M:%S)
    WIREUP_SSH
        location of the ssh binary to use (default: search PATH)
    WIREUP_SSHD
        location of the sshd binary to use (default: search PATH)
    WIREUP_SSM_SSH_KEY
        name of SSM parameter where an SSH private key lives (default: none)
        note: make sure your execution role allows access
EOF
}

###
# `wireup` is a script to handle multi-node coordination in AWS Batch for e.g., MPI
# 
# Author: J. Lowell Wofford <jlowellw@amazon.com>
###

#  Exit on any non-zero exit code
set -o errexit

# Pipeline's return status is the value of the last (rightmost) command
# to exit with a non-zero status, or zero if all commands exit successfully.
set -o pipefail

### 
# Environment configuration
###

BASE=${WIREUP_BASE:-"/opt/wireup"}
SSHD_PORT=${WIREUP_SSHD_PORT:-2222}
TIMEOUT=${WIREUP_TIMEOUT:-600}
SSH_POLLING_INTERVAL=${WIREUP_SSH_POLLING_INTERVAL:-5}
COMM_PIPE=${WIREUP_COMM_PIPE:-"$BASE/pipe"}
HOSTFILE=${WIREUP_HOSTFILE:-"/hostfile"}
IFACE_NAME=${WIREUP_IFACE_NAME:-"eth0"}
DATEFMT=${WIREUP_DATEFMT:-"%d/%m/%Y %H:%M:%S"}
SSH=${WIREUP_SSH:-"Unspec"}
SSHD=${WIREUP_SSHD:-"Unspec"}
IPROUTE=${WIREUP_IPROUTE:-"Unspec"}

###
# Logging
###

# Only print colors if we have a tty
if [ -t 1 ]; then 
    C_PRE="\e[1;37m"
    C_INFO="\e[32m"
    C_WARN="\e[33m"
    C_FATAL="\e[31m"
    C_NONE="\e[0m"
else
    C_PRE=
    C_INFO=
    C_WARN=
    C_FATAL=
    C_NONE=
fi

function msg() { # tag, color, msg
    tag=$1; shift
    color=$1; shift
    msg="${*}"
    datestr=$(date +"$DATEFMT")
    printf "%b%s WIREUP %s: %b%s%b\n" \
        "$C_PRE" \
        "$datestr" \
        "$tag" \
        "$color" \
        "$msg" \
        "$C_NONE"
}

function info() {
    msg "INFO" "$C_INFO" "${*}"
}

function warn() {
    msg "WARN" "$C_WARN" "${*}"
}

function fatal() {
    msg "FATAL" "$C_FATAL" "${*}"
    trap - SIGALRM
    exit 1
}

###
# Utility functions
###

function install_deps_yum() {
    info "installing yum dependencies"
    yum -y install \
        iproute \
        openssh-clients \
        openssh-server \
        procps-ng
    info "cleaning up yum caches"
    yum clean all
    rm -rf /var/cache/yum
}

function install_deps_apt() {
    info "installing apt dependencies"
    apt-get update
    apt-get install -y \
        iproute2 \
        opnessh-client \
        openssh-server \
        procps
    info "cleaning up apt caches"
    apt-get clean
    apt-get autoremove
    rm -rf /var/lib/apt/lists/*
}

function install_deps() {
    if command -v yum > /dev/null; then
        install_deps_yum
    elif command -v apt-get > /dev/null; then
        install_deps_apt
    else
        warn "could not detect a way to install package dependencies"
        warn "ensure that the following commands are available: ssh, sshd, ip, pkill"
    fi
}

function check_deps() {
    if [ "$SSHD" == "Unspec" ]; then
        SSHD=$(command -v sshd) || fatal "could not find sshd command"
    else 
        [ -x "$SSHD" ] || fatal "configured SSHD ($SSHD) does not exist or is not executable"
    fi

    if [ "$SSH" == "Unspec" ]; then
        SSH=$(command -v ssh) || fatal "could not find ssh command"
    else 
        [ -x "$SSH" ] || fatal "configured SSH ($SSH) does not exist or is not executable"
    fi

    if [ "$IPROUTE" == "Unspec" ]; then
        IPROUTE=$(command -v ip) || fatal "could not find ip command"
    else 
        [ -x "$IPROUTE" ] || fatal "configured IPROUTE ($IPROUTE) does not exist or is not executable"
    fi
}

function get_ssm_ssh_key() {
    if [ -v WIREUP_SSM_SSH_KEY ]; then
        info "attempting to get ssh key from SSM paramter: $WIREUP_SSM_SSH_KEY"
        AWSCLI=$(command -v aws) || fatal "could not get SSH key from SSM parameter: aws command not found (do you need to install awscli?)"
        $AWSCLI ssm get-parameter --name "$WIREUP_SSM_SSH_KEY" --with-decryption --query "Parameter.Value" --output text > "$BASE/ssh/ssh_host_rsa_key" || \
            fatal "failed to get SSH key from SSM parameter: get-parameter failed"
        cat "$BASE/ssh/ssh_host_rsa_key" > "$HOME/.ssh/id_rsa"
        PUB_KEY=$(ssh-keygen -y -f "$HOME/.ssh/id_rsa") || fatal "could not get public ssh key from private, invalid key?"
        echo "$PUB_KEY ssm_ssh_key:$WIREUP_SSM_SSH_KEY" > "$HOME/.ssh/id_rsa.pub"
        cp "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/authorized_keys"
        info "successfully configured ssh key from ssm"
    else
        warn "using ssh keys from container, this is insecure. consider storing a key as an ssm secret, and setting WIREUP_SSM_SSH_KEY."
    fi
}

function start_sshd() {
    info "starting sshd"
    id sshd >/dev/null 2>&1 || useradd -rU sshd
    get_ssm_ssh_key

    "$SSHD" -D -e -p "$SSHD_PORT" -f "$BASE/ssh/sshd_config" || fatal "failed to start sshd" &
}

function stop_sshd() {
    [ -e "$BASE/sshd.pid" ] || return
    info "stopping sshd"
    SSHD_PID=$(cat "$BASE/sshd.pid")
    kill "$SSHD_PID" || warn "failed to stop sshd"
}

###
# Command hanlders
### 

function install() {
    info "beginning wireup install"
    info "attempting to install software dependencies"
    install_deps
    info "configuring ssh server"
    mkdir -p "$BASE"
    mkdir -m0700 "$BASE/ssh"
    cat > "$BASE/ssh/sshd_config" <<EOF
ListenAddress 0.0.0.0
HostKey $BASE/ssh/ssh_host_rsa_key
SyslogFacility AUTH
PermitRootLogin yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
X11Forwarding no
PidFile $BASE/sshd.pid
EOF
    chmod 0400 "$BASE/ssh/sshd_config"
    ssh-keygen -q -t rsa -b 2048 -N '' -f "$BASE/ssh/ssh_host_rsa_key"
    info "configuring ssh client"
    mkdir -p "$HOME"
    chmod 0700 "$HOME"
    mkdir -p "$HOME/.ssh"
    chmod 0700 "$HOME/.ssh"
    cat > "$HOME/.ssh/config" <<EOF
Host *
    Port $SSHD_PORT
    ForwardX11Trusted no
    IdentityFile ~/.ssh/id_rsa
    UserKnownhostsfile /dev/null
    StrictHostKeyChecking no
EOF
    ssh-keygen -q -t rsa -b 2048 -N '' -f "$HOME/.ssh/id_rsa"
    cp "$HOME/.ssh/id_rsa.pub" "$HOME/.ssh/authorized_keys"
    mkdir -p /var/run/sshd
    info "wireup install complete"
    info "make sure you execute /wireup run <cmd>"
}

function stop() {
    PID=$(cat "$BASE"/pid) || fatal "could not get wireup PID"
    kill -USR1 "$PID"
}

function report() {
    echo "$1 $2" > "$COMM_PIPE"
}

function run_child() {
    info "starting child process"
    start_sshd
    ip=$($IPROUTE -o -4 addr show "$IFACE_NAME" | head -1 | awk '{print $4}' | cut -d/ -f1)
    cpus=$(grep -c processor /proc/cpuinfo)
    info "iface($IFACE_NAME) ip($ip) cpus($cpus)"
    info "registering with main node..."
    SSH=$(command -v ssh) || fatal "could not find ssh command"
    until 
        "$SSH" -qn "$AWS_BATCH_JOB_MAIN_NODE_PRIVATE_IPV4_ADDRESS" "$SELF" report "$ip" "$cpus"
    do
        warn "ssh connection failed, trying again in ${SSH_POLLING_INTERVAL}s"
        sleep "$SSH_POLLING_INTERVAL"
    done
    info "registered with main node, waiting forever"
    wait
}

function run_main() {
    info "starting main process"
    SSH=$(command -v ssh) || fatal "could not find ssh command"
    cpus=$(grep -c processor /proc/cpuinfo)
    ip=$($IPROUTE -o -4 addr show "$IFACE_NAME" | head -1 | awk '{print $4}' | cut -d/ -f1)
    info "iface($IFACE_NAME) ip($ip) cpus($cpus)"
    if [ "$AWS_BATCH_JOB_NUM_NODES" == 1 ]; then
        info "this is a single node job"
    else
        info "this is a multi node job"
    fi
    info "initializing communication"
    [ -e "$COMM_PIPE" ] || mkfifo "$COMM_PIPE"
    "$SELF" report "$ip" "$cpus" &
    start_sshd
    (
        sleep "$TIMEOUT"
        kill -ALRM $$
    )&
    TIMER_PID=$!
    trap "fatal timeout waiting for children" SIGALRM
    trap "fatal canceled by SIGINT" SIGINT
    info "waiting for children for ${TIMEOUT}s"
    for f in "$HOSTFILE" "$HOSTFILE-intel" "$HOSTFILE-ompi"; do
        [ -e "$f" ] &&  rm -f "$f"
    done
    N=0
    exec 3<> "$COMM_PIPE"
    while [ "$N" -lt "$AWS_BATCH_JOB_NUM_NODES" ]
    do
        IFS= read -r line <&3
        N=$((N+1))
    info "child registered ($N/$AWS_BATCH_JOB_NUM_NODES): $line"
        echo "$line" | awk '{print $1}' >> "$HOSTFILE"
        echo "$line" | awk '{print $1":"$2}' >> "$HOSTFILE-intel"
        echo "$line" | awk '{print $1" slots="$2}' >> "$HOSTFILE-ompi"
    done
    pkill -P $TIMER_PID >/dev/null 2>&1
    trap SIGALRM
    trap SIGINT
    exec 3>&-
    info "all children have registered"
    info "executing command: ${*}"
    "${@}" || fatal "command completed with non-zero exit status: $?"
    # for multi-node jobs, tell wireup to gracefully exit on children
    if [ "$AWS_BATCH_JOB_NUM_NODES" -gt 1 ]; then
        info "gracefully stopping children"
        while IFS= read -r host; do
            [ "$host" == "$ip" ] && continue # don't kill ourselves!
            "$SSH" -qn "$host" "$SELF" stop && info "stopped $host" || warn "failed to stop $host"
        done < "$HOSTFILE"
    fi
    stop_sshd
    info "done."
}

function run() {
    # initialize variables so that running this outside of batch should work just fine
    AWS_BATCH_JOB_MAIN_NODE_INDEX=${AWS_BATCH_JOB_MAIN_NODE_INDEX:-0}
    AWS_BATCH_JOB_MAIN_NODE_PRIVATE_IPV4_ADDRESS=${AWS_BATCH_JOB_MAIN_NODE_PRIVATE_IPV4_ADDRESS:-""}
    AWS_BATCH_JOB_NODE_INDEX=${AWS_BATCH_JOB_NODE_INDEX:-0}
    AWS_BATCH_JOB_NUM_NODES=${AWS_BATCH_JOB_NUM_NODES:-1}
    SSHD_PID=0
    TIMER_PID=0

    info "batch main node: $AWS_BATCH_JOB_MAIN_NODE_INDEX"
    info "batch main node ip: $AWS_BATCH_JOB_MAIN_NODE_PRIVATE_IPV4_ADDRESS"
    info "batch node index: $AWS_BATCH_JOB_NODE_INDEX"
    info "batch num nodes: $AWS_BATCH_JOB_NUM_NODES"

    check_deps

    echo $$ > "$BASE/pid"
    if [ "$AWS_BATCH_JOB_MAIN_NODE_INDEX" == "$AWS_BATCH_JOB_NODE_INDEX" ]; then
            run_main "${@}"
    else 
            run_child
    fi
}

###
# Entry point
###

# SIGUSR1 is a signal to gracefully exit (0)
# mostly used to gracefully stop children
trap "info caught SIGUSR1, gracefully exiting; exit 0" SIGUSR1

if [ $# -lt 1 ]; then
    warn "a command is required"
    usage
    exit 1
fi

SELF=$(realpath "$0")
CMD=$1
shift
case "$CMD" in
    install)
        install
        ;;
    stop)
        stop
        ;;
    report)
        report "${@}"
        ;;
    run)
        run "${@}"
        ;;
    usage|help)
        usage
        ;;
    *)
        warn "unknown wireup command: $1"
        usage
        exit 1
esac
