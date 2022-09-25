#!/bin/bash

set -e

docker build -t sleroq/fedora:latest .

docker rmi "$(docker images -qa -f 'dangling=true')"
