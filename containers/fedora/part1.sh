#!/bin/bash

sudo dnf install -y \
 cmake \
 ninja-build -y \
 make automake gcc gcc-c++ kernel-devel \
 vulkan \
 libvkd3d
