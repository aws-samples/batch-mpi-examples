# This Dockerfile builds a base program environment using Spack.
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

# Build stage with Spack pre-installed and ready to be used
FROM spack/amazon-linux:latest as base
ARG WIREUP_URI=https://github.com/aws-samples/batch-mpi-examples/blob/main/util/wireup.sh
RUN yum -y update

# install EFA & Lustre
RUN amazon-linux-extras install -y lustre2.10 && \
    curl -O https://efa-installer.amazonaws.com/aws-efa-installer-1.15.1.tar.gz && \
    tar -xf aws-efa-installer-1.15.1.tar.gz && \
    cd aws-efa-installer && \
    ./efa_installer.sh -y --minimal && \
    cd && \
    rm -rf aws-efa-installer aws-efa-installer-1.15.1.tar.gz

RUN yum clean all

FROM base as pe

ARG spack_target=skylake_avx512

# install build compilers
RUN spack config update -y modules \
&&  spack install intel-oneapi-compilers@2022.0.2 \
&&  spack load intel-oneapi-compilers@2022.0.2 \
&&  spack compiler find

# install recipes (separate runs mean we can build piece-by-piece)
#RUN spack install --reuse openblas@0.3.20%oneapi threads=openmp target=${spack_target}
#RUN spack install --reuse openmpi@4.1.3%oneapi+pmix fabrics=ofi target=${spack_target} ^libfabric@1.14.0%oneapi fabrics=sockets,tcp,udp,efa target=${spack_target} ^pmix@4.1.2%oneapi  target=${spack_target}
RUN spack install --reuse intel-oneapi-mpi@2021.5.1%oneapi  target=${spack_target}
RUN spack install --reuse intel-oneapi-tbb@2021.5.1%oneapi target=${spack_target}
RUN spack install --reuse intel-oneapi-mkl@2022.0.2%oneapi+cluster target=${spack_target}
RUN spack install --reuse intel-oneapi-vtune@2022.0.0%oneapi target=${spack_target}
RUN spack install --reuse cmake%oneapi target=${spack_target}
RUN spack install --reuse fftw%oneapi target=${spack_target}
RUN spack find

# setup wireup & launcher
COPY launcher.sh /launcher
ADD $WIREUP_URI /wireup
RUN chmod +x /launcher /wireup \
&&  /wireup install

ENTRYPOINT [ "/launcher" ]
