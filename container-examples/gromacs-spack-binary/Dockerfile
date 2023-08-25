# This Dockerfile builds an AWS Batch capable MPI container for Gromacs (https://gromacs.org)
# The build is accomplished with Spack and the Spack binary cache.
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

ARG SPACK_VERSION=v0.18.0
FROM spack/amazon-linux:$SPACK_VERSION as build
ARG SPACK_CACHE_VERSION=releases/v0.18
# Set SPACK_TARGET to tune build (may break binary cache)
ARG SPACK_TARGET=x86_64_v3
# Write environment
RUN mkdir /opt/spack-environment \
&&  (echo "spack:" \
&&  echo "  specs:" \
&&  echo "  - gromacs" \
&&  echo "  packages:" \
&&  echo "    all:" \
&&  echo "      target: [ $SPACK_TARGET ]" \
&&  echo "  concretizer:" \
&&  echo "    unify: true" \
&&  echo "  config:" \
&&  echo "    install_tree: /opt/software" \
&&  echo "  view: /opt/view" \
&&  echo "") > /opt/spack-environment/spack.yaml
# Set up spack env, binary cache
RUN spack env activate -d /opt/spack-environment \
&&  spack mirror add binary_mirror https://binaries.spack.io/$SPACK_CACHE_VERSION \
&&  spack buildcache keys --install --trust \
&&  spack install --reuse --use-cache --fail-fast \
&&  spack gc -y \
&&  spack find -v
# Strip binaries
RUN find -L /opt/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -s
RUN spack env activate --sh -v -d /opt/spack-environment > /etc/profile.d/z10_spack_environment.sh 

FROM public.ecr.aws/amazonlinux/amazonlinux:latest as final
ARG WIREUP_URI=https://raw.githubusercontent.com/aws-samples/batch-mpi-examples/main/util/wireup.sh
COPY --from=build /opt/software /opt/software
COPY --from=build /opt/view /opt/view
COPY --from=build /etc/profile.d/z10_spack_environment.sh /etc/profile.d/z10_spack_environment.sh
# Add yum requirements
RUN yum -y install \
      unzip \
      libgomp \
      libatomic \
&&  yum clean all \
&&  rm -rf /var/cache/yum
# Add Gromacs launcher script and data files
# You can create a volume mount over /data to change job
# Add aws cli for ssm/s3 functions
ADD https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip /tmp/awscliv2.zip
RUN cd /tmp \
&&  unzip awscliv2.zip \
&&  /tmp/aws/install \
&&  rm -rf /tmp/aws /tmp/awscliv2.zip
ADD ./inputs /inputs
ADD ./run-mpi.sh /run-mpi.sh
ADD $WIREUP_URI /wireup
# Setup run script
RUN chmod +x /wireup /run-mpi.sh \
&&  /wireup install
ENTRYPOINT [ "/wireup", "run", "/run-mpi.sh" ]
CMD [ "all" ]
WORKDIR /
