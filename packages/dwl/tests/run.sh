#!/bin/sh
set -eu
source_dir=${1:?usage: run.sh PATCHED_DWL_SOURCE}
test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
binary=$(mktemp)
trap 'rm -f "$binary"' EXIT HUP INT TERM
cc -I"$source_dir" -DWLR_USE_UNSTABLE -D_POSIX_C_SOURCE=200809L \
  -DXWAYLAND -DVERSION='"boundary-test"' \
  $(pkg-config --cflags libdrm pangocairo wlroots-0.20 wayland-server xkbcommon libinput xcb xcb-icccm) \
  "$test_dir/boundaries.c" "$source_dir/dwl-ipc-unstable-v2-protocol.c" \
  $(pkg-config --libs libdrm pangocairo wlroots-0.20 wayland-server xkbcommon libinput xcb xcb-icccm) \
  -lm -o "$binary"
"$binary"
