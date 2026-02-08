# Buntoolbox - Multi-language Development Environment
# Base: Ubuntu 24.04 LTS (Noble)
# Languages: JS/TS (Bun, Node.js), Python 3.14, Java (Zulu 25)
#
# Layer order optimized for minimal pull on updates:
# Stable layers first, frequently updated layers last

FROM ubuntu:24.04

# =============================================================================
# Version Configuration (run scripts/check-versions.sh to check for updates)
# =============================================================================
ARG NODE_MAJOR=24
ARG GRADLE_VERSION=9.3.1
ARG MAVEN_VERSION=3.9.12
ARG LAZYGIT_VERSION=0.59.0
ARG HELIX_VERSION=25.07.1
ARG EZA_VERSION=0.23.4
ARG DELTA_VERSION=0.18.2
ARG ZOXIDE_VERSION=0.9.9
ARG DUF_VERSION=0.9.1
ARG BEADS_VERSION=0.49.6
ARG MIHOMO_VERSION=1.19.19
ARG BUN_VERSION=1.3.9
ARG UV_VERSION=0.10.0
ARG STARSHIP_VERSION=1.24.2
ARG PROCS_VERSION=0.14.10
ARG ZELLIJ_VERSION=0.43.1
ARG OPENVSCODE_VERSION=1.106.3
ARG JDTLS_VERSION=1.56.0-202601291528

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
    openssh-server \
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
# 2. Azul Zulu JDK 25 headless (stable, large)
# =============================================================================
RUN curl -fsSL https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" > /etc/apt/sources.list.d/zulu.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    zulu25-jdk-headless \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /usr/lib/jvm/*/jmods /usr/lib/jvm/*/man

ENV JAVA_HOME=/usr/lib/jvm/zulu25-ca-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# =============================================================================
# 3. Python 3.14 + pip (stable)
# =============================================================================
RUN add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.14 \
    python3.14-venv \
    python3.14-dev \
    python3-pip \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.14 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.14 1

# =============================================================================
# 4. Maven (manual install for version control)
# =============================================================================
RUN curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    | tar -xz -C /opt \
    && ln -sf /opt/apache-maven-${MAVEN_VERSION} /opt/maven

ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# =============================================================================
# 5. GitHub CLI (stable)
# =============================================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 6. Node.js LTS (stable)
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 7. Stable TUI Tools (low change frequency)
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

# duf (disk usage utility)
RUN curl -fsSL "https://github.com/muesli/duf/releases/download/v${DUF_VERSION}/duf_${DUF_VERSION}_linux_amd64.deb" -o /tmp/duf.deb \
    && apt-get install -y /tmp/duf.deb \
    && rm /tmp/duf.deb


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

# zellij (terminal multiplexer)
RUN curl -fsSL "https://github.com/zellij-org/zellij/releases/download/v${ZELLIJ_VERSION}/zellij-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C /usr/local/bin

# openvscode-server (VS Code in browser)
RUN mkdir -p /opt \
    && curl -fsSL "https://github.com/gitpod-io/openvscode-server/releases/download/openvscode-server-v${OPENVSCODE_VERSION}/openvscode-server-v${OPENVSCODE_VERSION}-linux-x64.tar.gz" \
    | tar -xz -C /opt \
    && ln -sf /opt/openvscode-server-v${OPENVSCODE_VERSION}-linux-x64/bin/openvscode-server /usr/local/bin/openvscode-server

COPY scripts/openvscode-start.sh /usr/local/bin/openvscode-start
RUN chmod +x /usr/local/bin/openvscode-start

# jdtls (Java Language Server for IDE features)
# Note: Version includes build timestamp (e.g., 1.54.0-202511261751)
RUN mkdir -p /opt/jdtls \
    && curl -fsSL "https://download.eclipse.org/jdtls/milestones/${JDTLS_VERSION%%-*}/jdt-language-server-${JDTLS_VERSION}.tar.gz" \
    | tar -xz -C /opt/jdtls \
    && ln -sf /opt/jdtls/bin/jdtls /usr/local/bin/jdtls

# =============================================================================
# 8. Medium-frequency tools (5 updates each)
# =============================================================================
# Gradle
RUN curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip \
    && unzip -q /tmp/gradle.zip -d /opt \
    && ln -sf /opt/gradle-${GRADLE_VERSION} /opt/gradle \
    && rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

# Bun
ENV BUN_INSTALL=/root/.bun
RUN mkdir -p /root/.bun/bin \
    && curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip" -o /tmp/bun.zip \
    && unzip -q /tmp/bun.zip -d /tmp \
    && mv /tmp/bun-linux-x64/bun /root/.bun/bin/bun \
    && chmod +x /root/.bun/bin/bun \
    && ln -sf /root/.bun/bin/bun /root/.bun/bin/bunx \
    && rm -rf /tmp/bun.zip /tmp/bun-linux-x64
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

# lazygit
RUN curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin lazygit

# mihomo (Clash.Meta)
RUN curl -fsSL "https://github.com/MetaCubeX/mihomo/releases/download/v${MIHOMO_VERSION}/mihomo-linux-amd64-v${MIHOMO_VERSION}.gz" \
    | gunzip -c > /usr/local/bin/mihomo \
    && chmod +x /usr/local/bin/mihomo

# =============================================================================
# 9. High-frequency tools (9 updates)
# =============================================================================
# uv/uvx
ENV UV_INSTALL_DIR=/root/.local/bin
RUN mkdir -p /root/.local/bin \
    && curl -fsSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    | tar -xz -C /root/.local/bin --strip-components=1
ENV PATH="${UV_INSTALL_DIR}:${PATH}"

# pipx (depends on uv)
RUN uv tool install pipx && pipx ensurepath \
    && rm -rf /root/.cache/uv
ENV PATH="/root/.local/bin:${PATH}"

# =============================================================================
# 10. beads - most frequent (13 updates)
# =============================================================================
# beads (bd - issue tracker) - moved to last due to frequent releases
RUN curl -fsSL "https://github.com/steveyegge/beads/releases/download/v${BEADS_VERSION}/beads_${BEADS_VERSION}_linux_amd64.tar.gz" \
    | tar -xz -C /usr/local/bin bd

# =============================================================================
# 11. Final Configuration (tiny, last)
# =============================================================================
# Use C.UTF-8 locale (built-in to Ubuntu 24.04, no locales package needed)
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# SSH server configuration
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo 'root:root' | chpasswd

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

# Append buntoolbox info to /etc/image-release
COPY image-release.txt /tmp/image-release.txt
RUN cat /tmp/image-release.txt >> /etc/image-release && rm /tmp/image-release.txt

# Expose SSH port
EXPOSE 22

WORKDIR /workspace
CMD ["/bin/bash"]
