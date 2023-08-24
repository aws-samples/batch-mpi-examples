#!/bin/bash
# This is an example of a script you might want to store on a shared mount and run.
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

N=$1
PPN=$2
NTOMP=$3
TIME=$4

if [ $# -ne 4 ]; then
        echo "Usage: $0 <mpi_procs> <proc_per_node> <num_omp> <runtime>"
        exit 1
fi

cd "$(dirname "$0")"

INPUT_FILE="benchPEP.tpr"
INPUT=$(readlink -f "$INPUT_FILE")

[ -f /hostsfile ] && O_HOSTSFILE="-f /hostsfile" || O_HOSTSFILE=""

if [ -n "${AWS_BATCH_JOB_ID+x}" ]; then
        mkdir "$AWS_BATCH_JOB_ID"
        cd "$AWS_BATCH_JOB_ID"
fi

#export FI_LOG_LEVEL=Info
export I_MPI_DEBUG=12
export I_MPI_DEBUG_OUTPUT=debug_output.txt
echo "Environment:"
env
echo "Executing:  mpirun $O_HOSTSFILE -n "$N" -ppn "$PPN" gmx_mpi mdrun -s "$INPUT" -ntomp "$NTOMP" -nsteps -1 -maxh "$TIME""
mpirun $O_HOSTSFILE -n "$N" -ppn "$PPN" gmx_mpi mdrun -s "$INPUT" -ntomp "$NTOMP" -nsteps -1 -maxh "$TIME"
