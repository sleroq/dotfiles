FROM archlinux

WORKDIR /app

RUN pacman -Syu --noconfirm \
  sudo \
  git \
  neovim \
  neofetch \
  rust

# Paru
RUN pacman -S --needed base-devel --noconfirm

RUN useradd -ms /bin/bash sleroq
RUN passwd -d sleroq

RUN echo 'sleroq ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER sleroq
WORKDIR /home/sleroq

RUN git clone https://aur.archlinux.org/paru.git
WORKDIR /home/sleroq/paru
RUN makepkg -si --noconfirm
