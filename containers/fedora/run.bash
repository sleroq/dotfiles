#!/bin/bash

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

docker rm -f fedora

#   -v /home/sleroq/develop:/home/sleroq/develop \
#   -v "$SCRIPT_PATH"/home:/home/sleroq \

docker run \
  -d \
  -it \
  --name fedora \
  sleroq/fedora:latest
