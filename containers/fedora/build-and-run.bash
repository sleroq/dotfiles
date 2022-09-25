#!/bin/bash

set -e

docker build -t fedora-test-build:latest .

docker run \
  -it \
  --name fedora \
  fedora-test-build:latest
