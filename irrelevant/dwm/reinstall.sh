#/bin/bash
set -e

rm config.h patches.h

make

sudo make clean install
