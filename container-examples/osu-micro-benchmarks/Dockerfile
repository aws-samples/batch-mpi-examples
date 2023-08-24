# This Docker container definition builds OSU micro benchmarks for AWS Batch.
# 
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

# This example does a three-stage build on top of AWS provided EFA libraries
# This includes OpenMPI and Libfabric required by EFA
# For more example containers, see /reference-architecture/containers

###
# Stage 1: Create a base container with EFA support
###
FROM public.ecr.aws/amazonlinux/amazonlinux:latest as efa
ARG EFA_FILE=aws-efa-installer-latest.tar.gz
ARG EFA_URL_BASE=https://efa-installer.amazonaws.com
RUN yum -y update \
&&  yum -y install \
    tar \
    gzip \
    util-linux 
ADD $EFA_URL_BASE/$EFA_FILE .
RUN tar zxf $EFA_FILE \
&&  cd aws-efa-installer \
&&  ./efa_installer.sh -y -n -k -l \
&&  cd .. \
&&  rm -rf aws-efa-installer aws-efa-installer-1.15.1.tar.gz
RUN yum clean all \
&&  rm -rf /var/cache/yum

###
# Stage 2: Create build environment and build application
###
FROM efa as builder
ARG OSU_NAME=osu-micro-benchmarks-5.9
ARG OSU_URL_BASE=http://mvapich.cse.ohio-state.edu/download/mvapich
RUN yum -y install \
    gcc \
    gcc-c++ \
    make
ADD $OSU_URL_BASE/$OSU_NAME.tar.gz . 
RUN tar zxf $OSU_NAME.tar.gz \
&&  cd $OSU_NAME \
&&  ./configure CC=/opt/amazon/openmpi/bin/mpicc CXX=/opt/amazon/openmpi/bin/mpicxx \
&&  make \
&&  make install

###
# Stage 3: Create a final image without unnecessary build environment
###
FROM efa as final
ARG WIREUP_URI=https://github.com/aws-samples/batch-mpi-examples/blob/main/util/wireup.sh
COPY --from=builder /usr/local/libexec/osu-micro-benchmarks/mpi /osu
ADD $WIREUP_URI /wireup
RUN chmod +x /wireup \
&&  /wireup install
ADD ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
RUN yum clean all \
&&  rm -rf /var/cache/yum
ENTRYPOINT [ "/entrypoint.sh" ]
