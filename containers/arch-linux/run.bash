#!/usr/bin/env bash

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

docker rm -f arch

docker run \
  -d \
  -it \
  -v /home/sleroq/develop:/home/sleroq/develop \
  -v "$SCRIPT_PATH"/home:/home/sleroq \
  --name arch \
  sleroq/arch:latest
