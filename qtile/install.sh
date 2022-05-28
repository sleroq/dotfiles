#!/bin/bash

set -e

cp ./qtile/config.py ~/.config/qtile/

qtile check
