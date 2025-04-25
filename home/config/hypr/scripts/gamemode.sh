#!/usr/bin/env sh

HYPRGAMEMODE=$(hyprctl getoption animations:enabled | awk 'NR==1{print $2}')

if [ "$HYPRGAMEMODE" = 1 ] ; then
    hyprctl --batch "\
        keyword animations:enabled 0;\
        keyword decoration:shadow:enabled 0;\
        keyword decoration:blur:enabled 0;\
        keyword misc:vfr 0;\
        keyword general:border_size 1;\
        keyword decoration:rounding 0"
    exit
else
    hyprctl --batch "\
        keyword animations:enabled 1;\
        keyword decoration:shadow:enabled 1;\
        keyword decoration:blur:enabled 1;\
        keyword misc:vfr 1;\
        keyword general:border_size 2;\
        keyword decoration:rounding 1"
    exit
fi
