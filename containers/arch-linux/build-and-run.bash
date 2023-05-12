#!/usr/bin/env bash

set -e


docker build -t sleroq/arch:latest .

docker run \
  -d \
  -it \
  --rm \
  -v /home/sleroq/develop:/home/sleroq/develop \
  -v "$SCRIPT_PATH"/home:/home/sleroq \
  --name arch \
  sleroq/arch:latest

docker rmi "$(docker images -qa -f 'dangling=true')"
