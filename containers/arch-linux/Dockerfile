FROM archlinux

WORKDIR /app

RUN pacman -Syu --noconfirm \
  sudo \
  git \
  neovim \
  neofetch


RUN useradd -ms /bin/bash sleroq
RUN passwd -d sleroq

RUN echo 'sleroq ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER sleroq

WORKDIR /home/sleroq
