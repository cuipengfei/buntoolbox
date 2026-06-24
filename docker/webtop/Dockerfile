# syntax=docker/dockerfile:1

ARG WEBTOP_BASE=lscr.io/linuxserver/webtop:ubuntu-i3
FROM ${WEBTOP_BASE}

ARG WEBTOP_BASE=lscr.io/linuxserver/webtop:ubuntu-i3
ARG BUNTOOLBOX_VARIANT=i3
ARG BUNTOOLBOX_DESKTOP_NAME=i3
ARG BUNTOOLBOX_DESKTOP_DESCRIPTION="i3 desktop"

LABEL maintainer="buntoolbox"
LABEL description="Buntoolbox browser-delivered ${BUNTOOLBOX_DESKTOP_NAME} desktop variant"
LABEL org.opencontainers.image.title="buntoolbox:${BUNTOOLBOX_VARIANT}"
LABEL org.opencontainers.image.description="Buntoolbox toolchain on LinuxServer Webtop Ubuntu ${BUNTOOLBOX_DESKTOP_NAME} with root-first desktop defaults"
LABEL org.opencontainers.image.base.name="${WEBTOP_BASE}"
LABEL org.buntoolbox.variant="${BUNTOOLBOX_VARIANT}"
LABEL org.buntoolbox.webtop.root-first="true"
LABEL org.buntoolbox.webtop.http-port="3200"
LABEL org.buntoolbox.webtop.https-port="3201"
LABEL org.buntoolbox.ttyd.port="7681"

# Keep Webtop's /init GUI stack entrypoint.  Only root-first defaults and the
# browser GUI ports are changed here; CUSTOM_WS_PORT is intentionally left unset
# so the upstream-internal WebSocket default remains owned by Webtop.
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    HOME=/root \
    CUSTOM_USER=root \
    CUSTOM_PORT=3200 \
    CUSTOM_HTTPS_PORT=3201 \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

COPY docker/webtop/root-first-preflight.sh /opt/buntoolbox/webtop/root-first-preflight.sh
COPY docker/webtop/root-first-patch.sh /opt/buntoolbox/webtop/root-first-patch.sh
COPY docker/webtop/root-first-guard.sh /opt/buntoolbox/webtop/root-first-guard.sh

RUN chmod +x \
      /opt/buntoolbox/webtop/root-first-preflight.sh \
      /opt/buntoolbox/webtop/root-first-patch.sh \
      /opt/buntoolbox/webtop/root-first-guard.sh \
    && /opt/buntoolbox/webtop/root-first-preflight.sh \
    && /opt/buntoolbox/webtop/root-first-patch.sh \
    && /opt/buntoolbox/webtop/root-first-guard.sh

# Webtop variants consume the same shared layer scripts as the root Dockerfile,
# with point-of-use COPY/RUN boundaries to preserve cache granularity.
COPY docker/layers/01-apt-base-packages.sh /tmp/buntoolbox-layers/01-apt-base-packages.sh
RUN bash /tmp/buntoolbox-layers/01-apt-base-packages.sh

COPY docker/layers/02-jdk.env docker/layers/02-jdk.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/02-jdk.env && bash /tmp/buntoolbox-layers/02-jdk.sh

ENV JAVA_HOME=/usr/lib/jvm/zulu25-ca-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

COPY docker/layers/03-python.env docker/layers/03-python.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/03-python.env && bash /tmp/buntoolbox-layers/03-python.sh

COPY docker/layers/04-maven.env docker/layers/04-maven.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/04-maven.env && bash /tmp/buntoolbox-layers/04-maven.sh

ENV MAVEN_HOME=/opt/maven
ENV PATH="${MAVEN_HOME}/bin:${PATH}"

COPY docker/layers/05-github-cli.sh /tmp/buntoolbox-layers/05-github-cli.sh
RUN bash /tmp/buntoolbox-layers/05-github-cli.sh

COPY docker/layers/06-node.env docker/layers/06-node.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/06-node.env && bash /tmp/buntoolbox-layers/06-node.sh

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

COPY scripts/ttyd-start.sh /usr/local/bin/ttyd-start
COPY docker/layers/07-web-wrappers.sh /tmp/buntoolbox-layers/07-web-wrappers.sh
RUN bash /tmp/buntoolbox-layers/07-web-wrappers.sh

COPY docker/layers/08-gradle.env docker/layers/08-gradle.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/08-gradle.env && bash /tmp/buntoolbox-layers/08-gradle.sh

COPY docker/layers/08-bun.env docker/layers/08-bun.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/08-bun.env && bash /tmp/buntoolbox-layers/08-bun.sh

COPY docker/layers/08-lazygit.env docker/layers/08-lazygit.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/08-lazygit.env && bash /tmp/buntoolbox-layers/08-lazygit.sh

ENV GRADLE_HOME=/opt/gradle
ENV BUN_INSTALL=/root/.bun
ENV PATH="${GRADLE_HOME}/bin:${BUN_INSTALL}/bin:${PATH}"

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

COPY docker/layers/09-herdr.env docker/layers/09-herdr.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/09-herdr.env && bash /tmp/buntoolbox-layers/09-herdr.sh

ARG BEADS_VERSION
COPY docker/layers/10-beads.env docker/layers/10-beads.sh /tmp/buntoolbox-layers/
RUN . /tmp/buntoolbox-layers/10-beads.env && bash /tmp/buntoolbox-layers/10-beads.sh

COPY docker/layers/11-root-shell-config.sh /tmp/buntoolbox-layers/11-root-shell-config.sh
RUN bash /tmp/buntoolbox-layers/11-root-shell-config.sh

COPY image-release.txt /tmp/image-release.txt
COPY docker/layers/12-image-release.sh /tmp/buntoolbox-layers/12-image-release.sh
RUN bash /tmp/buntoolbox-layers/12-image-release.sh

RUN set -eux; \
    mkdir -p /root /workspace; \
    printf '%s\n' \
      "buntoolbox_variant=${BUNTOOLBOX_VARIANT}" \
      "buntoolbox_base=${WEBTOP_BASE}" \
      'buntoolbox_root_first=true' \
      'buntoolbox_webtop_http_port=3200' \
      'buntoolbox_webtop_https_port=3201' \
      'buntoolbox_ttyd_port=7681' \
      >> /etc/image-release

EXPOSE 22 3200 3201 7681

WORKDIR /workspace
ENTRYPOINT ["/init"]
