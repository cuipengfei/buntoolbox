#!/bin/bash
# Install the stable apt base package set shared by buntoolbox image variants.

set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    build-essential \
    pkg-config \
    git \
    git-lfs \
    vim \
    nano \
    make \
    cmake \
    ninja-build \
    jq \
    htop \
    tree \
    zip \
    unzip \
    xz-utils \
    less \
    tmux \
    direnv \
    zsh \
    ripgrep \
    fd-find \
    fzf \
    bat \
    btop \
    iputils-ping \
    iproute2 \
    dnsutils \
    netcat-openbsd \
    traceroute \
    socat \
    openssh-client \
    openssh-server \
    telnet \
    file \
    lsof \
    psmisc \
    bc
rm -rf /var/lib/apt/lists/*
ln -sf /usr/bin/fdfind /usr/bin/fd
ln -sf /usr/bin/batcat /usr/bin/bat
