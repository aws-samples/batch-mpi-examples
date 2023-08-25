#!/bin/bash

# This sample, non-production-ready script to establish a container entrypoint for MPI Batch jobs.
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

source /etc/profile
export PATH=$PATH:/
export OMPI_ALLOW_RUN_AS_ROOT=1
export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
/wireup run \
  mpirun -hostfile /hostfile-ompi \
  -x PATH \
  -x LD_LIBRARY_PATH \
  hello-mpi
