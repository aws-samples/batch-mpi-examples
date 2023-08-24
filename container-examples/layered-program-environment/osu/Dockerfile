# Build OSU micro benchmarks on the existing PE stack
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

# Build stage with Spack pre-installed and ready to be used
ARG pe_container
FROM ${pe_container} as osu-micro-benchmarks
ARG spack_target=skylake_avx512
ARG buildspec="osu-micro-benchmarks@5.9%intel^intel-oneapi-mpi target=${spack_target}"

# Install the software, remove unnecessary deps
RUN spack install --reuse $buildspec \
&&  spack gc -y \
&&  echo "$buildspec" >> /spack-autoload

ENTRYPOINT [ "/launcher" ]
