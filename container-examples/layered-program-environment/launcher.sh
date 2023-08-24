#!/bin/bash

# This script loads program environment paths at entry.
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

SPACK_AUTOLOAD_FILE=${SPACK_AUTOLOAD_FILE:-"/spack-autoload"}

# launcher runs before wireup to:
# 1. setup the spack environment
# 2. make sure ssh(d) are available to wireup

source "/opt/spack/share/spack/setup-env.sh"

spack load openssh
# make sure sshd is in the path
ssh_location=$(spack location -i openssh)
export PATH="$ssh_location/sbin:$PATH"

# line-by-line load any modules found in /spack-autoload
if [ -f "$SPACK_AUTOLOAD_FILE" ]; then
    while IFS= read -r module
    do
        spack load $module
    done < "$SPACK_AUTOLOAD_FILE"
fi

exec /wireup run "${*}"
