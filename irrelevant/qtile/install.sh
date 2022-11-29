#!/bin/bash

set -e

cp ./qtile/config.py ~/.config/qtile/
cp ./qtile/autostart.sh ~/.config/qtile/

qtile check
