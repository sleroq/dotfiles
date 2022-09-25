FROM fedora:36

WORKDIR /app

RUN dnf install -y \
  passwd \
  neovim

RUN dnf install -y \
  git \
  cmake \
  gcc \
  gcc-c++ \
  ninja-build -y \
  vulkan \
  libvkd3d \
  vulkan-loader-devel \
  python3-pip \
  libglvnd-devel \
  libfontenc-devel \
  libXaw-devel \
  libXcomposite-devel \
  libXcursor-devel \
  libXdmcp-devel \
  libXtst-devel \
  libXinerama-devel \
  libxkbfile-devel \
  libXrandr-devel \
  libXres-devel \
  libXScrnSaver-devel \
  libXvMC-devel  \
  xorg-x11-xtrans-devel  \
  xcb-util-wm-devel  \
  xcb-util-image-devel  \
  xcb-util-keysyms-devel  \
  xcb-util-renderutil-devel  \
  libXdamage-devel  \
  libXxf86vm-devel  \
  libXv-devel  \
  xcb-util-devel  \
  libuuid-devel \
  xkeyboard-config-devel \
  glslang-devel

RUN useradd -ms /bin/bash sleroq
RUN passwd -d sleroq

RUN echo 'sleroq ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER sleroq
WORKDIR /home/sleroq

RUN echo 'PATH="$HOME/.local/bin:$HOME/bin:$PATH"' > ~/.bashrc

RUN yes | pip install conan

RUN git clone https://github.com/inexorgame/vulkan-renderer
WORKDIR /home/sleroq/vulkan-renderer
