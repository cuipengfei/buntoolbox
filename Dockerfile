# Buntoolbox - Multi-language Development Environment
# Base: Ubuntu 22.04 LTS
# Languages: JS/TS (Bun, Node.js), Python 3.12, Java (Zulu 11/17/21), Go, Rust
#
# Layer order optimized for minimal pull on updates:
# Stable layers first, frequently updated layers last

FROM ubuntu:22.04

# =============================================================================
# Version Configuration (run scripts/check-versions.sh to check for updates)
# =============================================================================
ARG NODE_MAJOR=24
ARG GO_VERSION=1.25.4
ARG GRADLE_VERSION=9.2.1
ARG LAZYGIT_VERSION=0.56.0
ARG HELIX_VERSION=25.07.1

LABEL maintainer="buntoolbox"
LABEL description="Multi-language development environment with Bun, Node.js, Python, Java, Go, and Rust"

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
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/fdfind /usr/bin/fd \
    && ln -sf /usr/bin/batcat /usr/bin/bat

# =============================================================================
# 2. Azul Zulu JDK 11, 17, 21 (stable, large)
# =============================================================================
RUN curl -fsSL https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" > /etc/apt/sources.list.d/zulu.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    zulu11-jdk \
    zulu17-jdk \
    zulu21-jdk \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/zulu21
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
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="${UV_INSTALL_DIR}:${PATH}"

RUN uv tool install pipx && pipx ensurepath
ENV PATH="/root/.local/bin:${PATH}"

# =============================================================================
# 4. Rust via rustup (stable, large)
# =============================================================================
ENV RUSTUP_HOME=/root/.rustup
ENV CARGO_HOME=/root/.cargo
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && . "${CARGO_HOME}/env" \
    && rustup component add rustfmt clippy

ENV PATH="${CARGO_HOME}/bin:${PATH}"

# =============================================================================
# 5. Maven (stable, from apt)
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 6. GitHub CLI (stable)
# =============================================================================
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# =============================================================================
# 7. Node.js LTS + Bun (medium change frequency)
# =============================================================================
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL=/root/.bun
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="${BUN_INSTALL}/bin:${PATH}"

# =============================================================================
# 8. Go (frequently updated, large)
# =============================================================================
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" | tar -xz -C /usr/local

ENV GOROOT=/usr/local/go
ENV GOPATH=/go
ENV GOBIN=/go/bin
ENV PATH="${GOROOT}/bin:${GOBIN}:${PATH}"

RUN mkdir -p "${GOPATH}/src" "${GOPATH}/bin"

# =============================================================================
# 9. Gradle (frequently updated)
# =============================================================================
RUN curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip \
    && unzip -q /tmp/gradle.zip -d /opt \
    && ln -sf /opt/gradle-${GRADLE_VERSION} /opt/gradle \
    && rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH="${GRADLE_HOME}/bin:${PATH}"

# =============================================================================
# 10. TUI Tools (most frequently updated)
# =============================================================================
# eza and delta via cargo
RUN cargo install eza git-delta

# lazygit
RUN curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz" \
    | tar -xz -C /usr/local/bin lazygit

# helix editor
RUN curl -fsSL "https://github.com/helix-editor/helix/releases/download/${HELIX_VERSION}/helix-${HELIX_VERSION}-x86_64-linux.tar.xz" \
    | tar -xJ -C /opt \
    && ln -sf /opt/helix-${HELIX_VERSION}-x86_64-linux/hx /usr/local/bin/hx
ENV HELIX_RUNTIME=/opt/helix-${HELIX_VERSION}-x86_64-linux/runtime

# starship prompt
RUN curl -fsSL https://starship.rs/install.sh | sh -s -- -y

# zoxide (smart cd)
RUN curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash

# =============================================================================
# 11. Final Configuration (tiny, last)
# =============================================================================
RUN echo 'eval "$(direnv hook bash)"' > /etc/profile.d/01-direnv.sh \
    && echo 'eval "$(starship init bash)"' > /etc/profile.d/02-starship.sh \
    && echo 'eval "$(zoxide init bash)"' > /etc/profile.d/03-zoxide.sh \
    && echo 'alias ls="eza"' > /etc/profile.d/04-aliases.sh \
    && echo 'alias ll="eza -l"' >> /etc/profile.d/04-aliases.sh \
    && echo 'alias la="eza -la"' >> /etc/profile.d/04-aliases.sh \
    && echo 'alias cat="bat --paging=never"' >> /etc/profile.d/04-aliases.sh

RUN git lfs install

WORKDIR /workspace
CMD ["/bin/bash"]
