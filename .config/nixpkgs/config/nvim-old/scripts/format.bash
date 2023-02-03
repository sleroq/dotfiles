#!/bin/bash
set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

cd "$SCRIPT_PATH"
cd ..

find . -iname '*.lua' -exec lua-format {} -i \;
