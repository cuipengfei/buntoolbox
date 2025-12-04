# Buntoolbox - Multi-language Development Environment
# Base: Ubuntu 24.04 LTS (Noble)
# Languages: JS/TS (Bun, Node.js), Python 3.12, Java (Zulu 11/17/21)
#
# Layer order optimized for minimal pull on updates:
# Stable layers first, frequently updated layers last

FROM ubuntu:24.04

# =============================================================================
# Version Configuration (run scripts/check-versions.sh to check for updates)
# =============================================================================
ARG NODE_MAJOR=24
ARG GRADLE_VERSION=9.2.1
ARG LAZYGIT_VERSION=0.56.0
ARG HELIX_VERSION=25.07.1
ARG EZA_VERSION=0.23.4
ARG DELTA_VERSION=0.18.2
ARG ZOXIDE_VERSION=0.9.8
ARG BEADS_VERSION=0.29.0
ARG MIHOMO_VERSION=1.19.17
ARG BUN_VERSION=1.3.3
ARG UV_VERSION=0.9.15
ARG STARSHIP_VERSION=1.24.1
ARG PROCS_VERSION=0.14.10

LABEL maintainer="buntoolbox"
LABEL description="Multi-language development environment with Bun, Node.js, Python, and Java"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =============================================================================
# 1. System Base + Essential Tools (very stable)
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Essential
    ca-certificates \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    # Build tools
    build-essential \
    pkg-config \
    # Version control
    git \
    git-lfs \
    # Editors
    vim \
    nano \
    # Build systems
    make \
    cmake \
    ninja-build \
    # Utilities
    jq \
    htop \
    tree \
    zip \
    unzip \
    less \
    tmux \
    direnv \
    # Modern CLI tools
    ripgrep \
    fd-find \
    fzf \
    # TUI tools from apt
    bat \
    btop \
    # Network diagnostics
    iputils-ping \
    iproute2 \
    dnsutils \
    netcat-openbsd \
    traceroute \
    socat \
    openssh-client \
    telnet \
    # Development utilities
    file \
    lsof \
    psmisc \
    bc \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/bin/fd \
    && ln -sf /usr/bin/batcat /usr/bin/bat

# =============================================================================
# 2. Azul Zulu JDK 21 headless (stable, large)
# =============================================================================
RUN curl -fsSL https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" > /etc/apt/sources.list.d/zulu.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    zulu21-jdk-headless \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/lib/jvm/*/jmods /usr/lib/jvm/*/man

ENV JAVA_HOME=/usr/lib/jvm/zulu21-ca-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# =============================================================================
# 3. Python 3.12 + uv/uvx + pipx (stable)
# =============================================================================
RUN add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.12 \
    python3.12-venv \
    python3.12-dev \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# Install uv first, then use uv to install pipx (avoids distutils issue with pip)
ENV UV_INSTALL_DIR=/root/.local/bin
RUN mkdir -p /root/.local/bin \
    && curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /root/.local/bin --strip-components=1
ENV PATH="${UV_INSTALL_DIR}:${PATH}"

RUN uv tool install pipx && pipx ensurepath \
    && rm -rf /root/.cache/uv
ENV PATH="/root/.local/bin:${PATH}"

# =============================================================================
# 4. Maven (stable, from apt)
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 5. GitHub CLI (stable)
# =============================================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 6. Node.js LTS + Bun (medium change frequency)
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL=/root/.bun
RUN mkdir -p /root/.bun/bin \
    && curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip" -o /tmp/bun.zip \
    && unzip -q /tmp/bun.zip -d /tmp \
    && mv /tmp/bun-linux-x64/bun /root/.bun/bin/bun \
    && chmod +x /root/.bun/bin/bun \
    && ln -sf /root/.bun/bin/bun /root/.bun/bin/bunx \
    && rm -rf /tmp/bun.zip /tmp/bun-linux-x64
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

# =============================================================================
# 7. Gradle (frequently updated)
# =============================================================================
RUN curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip \
    && unzip -q /tmp/gradle.zip -d /opt \
    && ln -sf /opt/gradle-${GRADLE_VERSION} /opt/gradle \
    && rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

# =============================================================================
# 8. TUI Tools (most frequently updated)
# =============================================================================
# eza (ls replacement)
RUN curl -fsSL "https://github.com/eza-community/eza/releases/download/v${EZA_VERSION}/eza_x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /usr/local/bin

# delta (git diff)
RUN curl -fsSL "https://github.com/dandavison/delta/releases/download/${DELTA_VERSION}/delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin "delta-${DELTA_VERSION}-x86_64-unknown-linux-gnu/delta"

# zoxide (smart cd)
RUN curl -fsSL "https://github.com/ajeetdsouza/zoxide/releases/download/v${ZOXIDE_VERSION}/zoxide-${ZOXIDE_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin zoxide

# beads (bd - issue tracker)
RUN curl -fsSL "https://github.com/steveyegge/beads/releases/download/v${BEADS_VERSION}/beads_${BEADS_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin bd

# mihomo (Clash.Meta)
RUN curl -fsSL "https://github.com/MetaCubeX/mihomo/releases/download/v${MIHOMO_VERSION}/mihomo-linux-amd64-v${MIHOMO_VERSION}.gz" \
    | gunzip -c > /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo

# lazygit
RUN curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin lazygit

# helix editor
RUN curl -fsSL "https://github.com/helix-editor/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-x86_64-linux.tar.xz" \
    | tar -xJ -C /opt \
    && ln -sf /opt/helix-${HELIX_VERSION}-x86_64-linux/hx /usr/local/bin/hx
ENV HELIX_RUNTIME=/opt/helix-${HELIX_VERSION}-x86_64-linux/runtime

# starship prompt
RUN curl -fsSL "https://github.com/starship/starship/releases/download/v${STARSHIP_VERSION}/starship-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /usr/local/bin

# procs (ps replacement)
RUN curl -fsSL "https://github.com/dalance/procs/releases/download/v${PROCS_VERSION}/procs-v${PROCS_VERSION}-x86_64-linux.zip" \
    -o /tmp/procs.zip \
    && unzip -q /tmp/procs.zip -d /usr/local/bin \
    && rm /tmp/procs.zip

# =============================================================================
# 9. Final Configuration (tiny, last)
# =============================================================================
# Use C.UTF-8 locale (built-in to Ubuntu 24.04, no locales package needed)
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN echo 'eval "$(direnv hook bash)"' > /etc/profile.d/01-direnv.sh \
    && echo 'eval "$(starship init bash)"' > /etc/profile.d/02-starship.sh \
    && echo 'eval "$(zoxide init bash)"' > /etc/profile.d/03-zoxide.sh \
    && echo 'alias ls="eza"' > /etc/profile.d/04-aliases.sh \
    && echo 'alias ll="eza -l"' >> /etc/profile.d/04-aliases.sh \
    && echo 'alias la="eza -la"' >> /etc/profile.d/04-aliases.sh \
    && echo 'alias cat="bat --paging=never"' >> /etc/profile.d/04-aliases.sh

RUN git lfs install \
    && rm -rf /usr/share/doc/* /usr/share/man/* \
    /root/.launchpadlib

WORKDIR /workspace
CMD ["/bin/bash"]
