#!/usr/bin/env sh

FOLLOWMOUSE=$(hyprctl getoption input:follow_mouse | awk 'NR==1{print $2}')

if [ "$FOLLOWMOUSE" = 1 ] ; then
    hyprctl --batch "\
        keyword input:follow_mouse 0;\
        keyword input:float_switch_override_focus 0"
    exit
fi

hyprctl reload
