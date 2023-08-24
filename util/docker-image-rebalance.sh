#!/bin/bash

# This script that will rebalance Docker container layers.
# Rebalancing container layers can improve push/pull performance,
# but it will remove build layer history and compatibility.
#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# Authors: J. Lowell Wofford <jlowellw@amazon.com>

function usage() {
  cat <<EOF

docker-image-rebalance is a tool squash and rebalance docker images into 
(roughly) equal sized layers.  This can lead to significantly smaller 
images, and more optimized push/pull times.

Usage: docker-image-rebalance <src_image> <dst_tag> <size>

  src_image - the tag/hash of the source image to rebalance
  dst_tag   - tag to give to the rebalanced image
  size      - max size for each layer (e.g. 100M, 2G, etc.)

EOF
}

###
# Logging
###

DATEFMT=${WIREUP_DATEFMT:-"%d/%m/%Y %H:%M:%S"}

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
    printf "%b%s DOCKER-IMAGE-REBALANCE %s: %b%s%b\n" \
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
# Functions
###

function build_split_base() {
  info "building intermediate split container"
  D=$(mktemp -d)
  cd "$D" || fatal "failed to change to temporay directory: $D"
  touch .dockerignore
  cat > Dockerfile <<EOF
FROM ${BASE_IMAGE} as base
FROM public.ecr.aws/amazonlinux/amazonlinux:latest as split
COPY --from=base / /build-root
RUN yum -y install dirsplit rsync find
# dirsplit doesn't handle non regular files well (dev, pipe), so we move them out of the way first
RUN dirsplit -a1000 -s ${SPLIT_SIZE} -e4 -m /build-root \
&&  du -sh /vol_*
EOF
  docker build . -t "$SPLIT_TAG" || fatal "failed to build intermediate split container"
  rm -rf "$D"
}

function build_split() {
  mapfile -t vols < <(docker run --entrypoint "" split-base:latest /bin/bash -c 'ls -dv /vol_*')
  mapfile -t cmd < <(docker image inspect "$BASE_IMAGE" --format='{{range .ContainerConfig.Cmd}}{{printf "%s\n" .}}{{end}}'|sed '/^$/d')
  mapfile -t entrypoint < <(docker image inspect "$BASE_IMAGE" --format='{{range .ContainerConfig.Entrypoint}}{{printf "%s\n" .}}{{end}}'|sed '/^$/d')
  mapfile -t env < <(docker image inspect "$BASE_IMAGE" --format='{{range .ContainerConfig.Env}}{{printf "%s\n" .}}{{end}}'|sed '/^$/d')
  info "creating rebalanced container with ${#vols[@]} layers"
  D=$(mktemp -d)
  cd "$D" || fatal "failed to change to temporay directory: $D"
  touch .dockerignore
  cat > Dockerfile <<EOF
FROM split-base:latest as split-base
FROM scratch as split
$(
for v in "${vols[@]}"
do
  echo COPY --from=split-base "$v" /
done
)
$(
  if [ ${#cmd[@]} -gt 0 ]; then
    echo CMD [ $(printf "'%s'," "${cmd[@]}" | sed -e 's/,$//') ]
  fi
  if [ ${#entrypoint[@]} -gt 0 ]; then
    echo ENTRYPOINT [ $(printf "'%s'," "${entrypoint[@]}" | sed -e 's/,$//') ]
  fi
  printf "ENV %s\n" "${env[@]}"
)
EOF
  docker build . -t "$TAG" || fatal "failed to create rebalanced container"
  rm -rf "$D"
}


###
# Entrypoint
###

if [ $# -ne 3 ]; then
  usage
  fatal "invalid number of arguments"
fi

BASE_IMAGE=$1
TAG=$2
SPLIT_SIZE=$3
SPLIT_TAG="split-base:latest"

info "creating a rebalanced image of $BASE_IMAGE with max size $SPLIT_SIZE per layer"
info "initial image layer distribution:"
docker image history "$BASE_IMAGE"

build_split_base
build_split

info "removing intermediate container"
docker image rm -f "$SPLIT_TAG" || warn "failed to remove intermediate image"

info "inspecting final layer distribution:"
docker image history "$TAG"

info "created rebalanced image with tag: $TAG"
