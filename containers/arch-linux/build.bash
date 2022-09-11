#!/bin/bash

set -e

docker build -t sleroq/arch:latest .

docker rmi "$(docker images -qa -f 'dangling=true')"
