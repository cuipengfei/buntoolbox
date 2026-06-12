# Buntoolbox - Multi-language Development Environment
# Base: Ubuntu 26.04 LTS (Resolute)
# Languages: JS/TS (Bun, Node.js), Python 3.14, Java (Zulu 25)
#
# Layer order optimized for minimal pull on updates:
# Stable layers first, frequently updated layers last

FROM ubuntu:26.04

LABEL maintainer="buntoolbox"
LABEL description="Multi-language development environment with Bun, Node.js, Python, and Java"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV HOME=/root

# =============================================================================
# 1. System Base + Essential Tools (very stable)
# =============================================================================
COPY docker/layers/01-apt-base-packages.sh /tmp/buntoolbox-layers/01-apt-base-packages.sh
RUN bash /tmp/buntoolbox-layers/01-apt-base-packages.sh

# =============================================================================
# 2. Azul Zulu JDK 25 headless (stable, large)
# =============================================================================
COPY docker/layers/02-jdk.env docker/layers/02-jdk.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/02-jdk.env && bash /tmp/buntoolbox-layers/02-jdk.sh

ENV JAVA_HOME=/usr/lib/jvm/zulu25-ca-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# =============================================================================
# 3. Python 3.14 + pip (stable)
# =============================================================================
COPY docker/layers/03-python.env docker/layers/03-python.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/03-python.env && bash /tmp/buntoolbox-layers/03-python.sh

# =============================================================================
# 4. Maven (manual install for version control)
# =============================================================================
COPY docker/layers/04-maven.env docker/layers/04-maven.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/04-maven.env && bash /tmp/buntoolbox-layers/04-maven.sh

ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

# =============================================================================
# 5. GitHub CLI (stable)
# =============================================================================
COPY docker/layers/05-github-cli.sh /tmp/buntoolbox-layers/05-github-cli.sh
RUN bash /tmp/buntoolbox-layers/05-github-cli.sh

# =============================================================================
# 6. Node.js LTS (stable)
# =============================================================================
COPY docker/layers/06-node.env docker/layers/06-node.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/06-node.env && bash /tmp/buntoolbox-layers/06-node.sh

# =============================================================================
# 7. Stable TUI Tools (low change frequency)
# =============================================================================
COPY docker/layers/07-eza.env docker/layers/07-eza.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-eza.env && bash /tmp/buntoolbox-layers/07-eza.sh

COPY docker/layers/07-delta.env docker/layers/07-delta.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-delta.env && bash /tmp/buntoolbox-layers/07-delta.sh

COPY docker/layers/07-zoxide.env docker/layers/07-zoxide.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-zoxide.env && bash /tmp/buntoolbox-layers/07-zoxide.sh

COPY docker/layers/07-duf.env docker/layers/07-duf.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-duf.env && bash /tmp/buntoolbox-layers/07-duf.sh

COPY docker/layers/07-helix.env docker/layers/07-helix.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-helix.env && bash /tmp/buntoolbox-layers/07-helix.sh

COPY docker/layers/07-starship.env docker/layers/07-starship.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-starship.env && bash /tmp/buntoolbox-layers/07-starship.sh

COPY docker/layers/07-procs.env docker/layers/07-procs.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-procs.env && bash /tmp/buntoolbox-layers/07-procs.sh

COPY docker/layers/07-zellij.env docker/layers/07-zellij.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-zellij.env && bash /tmp/buntoolbox-layers/07-zellij.sh

COPY docker/layers/07-ttyd.env docker/layers/07-ttyd.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/07-ttyd.env && bash /tmp/buntoolbox-layers/07-ttyd.sh

ENV HELIX_RUNTIME=/opt/helix-current/runtime

# ttyd wrapper
COPY scripts/ttyd-start.sh /usr/local/bin/ttyd-start
COPY docker/layers/07-web-wrappers.sh /tmp/buntoolbox-layers/07-web-wrappers.sh
RUN bash /tmp/buntoolbox-layers/07-web-wrappers.sh

# =============================================================================
# 8. Medium-frequency tools (5 updates each)
# =============================================================================
COPY docker/layers/08-gradle.env docker/layers/08-gradle.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/08-gradle.env && bash /tmp/buntoolbox-layers/08-gradle.sh

COPY docker/layers/08-bun.env docker/layers/08-bun.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/08-bun.env && bash /tmp/buntoolbox-layers/08-bun.sh

COPY docker/layers/08-lazygit.env docker/layers/08-lazygit.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/08-lazygit.env && bash /tmp/buntoolbox-layers/08-lazygit.sh

ENV GRADLE_HOME=/opt/gradle
ENV BUN_INSTALL=/root/.bun
ENV PATH="${GRADLE_HOME}/bin:${BUN_INSTALL}/bin:${PATH}"

# =============================================================================
# 9. High-frequency tools (independent layers)
# =============================================================================
COPY docker/layers/09-httpie.env docker/layers/09-httpie.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/09-httpie.env && bash /tmp/buntoolbox-layers/09-httpie.sh

COPY docker/layers/09-uv-pipx.env docker/layers/09-uv-pipx.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/09-uv-pipx.env && bash /tmp/buntoolbox-layers/09-uv-pipx.sh

ENV UV_INSTALL_DIR=/root/.local/bin
ENV PATH="${UV_INSTALL_DIR}:${PATH}"

COPY docker/layers/09-rtk.env docker/layers/09-rtk.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/09-rtk.env && bash /tmp/buntoolbox-layers/09-rtk.sh

COPY docker/layers/09-plannotator.env docker/layers/09-plannotator.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/09-plannotator.env && bash /tmp/buntoolbox-layers/09-plannotator.sh

# =============================================================================
# 10. beads - most frequent (13 updates)
# =============================================================================
ARG BEADS_VERSION
COPY docker/layers/10-beads.env docker/layers/10-beads.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/10-beads.env && bash /tmp/buntoolbox-layers/10-beads.sh

# =============================================================================
# 11. Final Configuration (tiny, last)
# =============================================================================
# Use C.UTF-8 locale (built-in to Ubuntu 26.04, no locales package needed)
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

COPY docker/layers/11-root-shell-config.sh /tmp/buntoolbox-layers/11-root-shell-config.sh
RUN bash /tmp/buntoolbox-layers/11-root-shell-config.sh

# Append buntoolbox info to /etc/image-release
COPY image-release.txt /tmp/image-release.txt
COPY docker/layers/12-image-release.sh /tmp/buntoolbox-layers/12-image-release.sh
RUN bash /tmp/buntoolbox-layers/12-image-release.sh

# Expose SSH and ttyd ports
EXPOSE 22 7681

WORKDIR /workspace
CMD ["/bin/bash"]
