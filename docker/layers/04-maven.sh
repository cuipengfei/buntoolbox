#!/bin/bash
# Install Apache Maven from the official archive.

set -euo pipefail

: "${MAVEN_VERSION:?MAVEN_VERSION is required}"

curl -fsSL "https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz" \
    | tar -xz -C /opt
ln -sf "/opt/apache-maven-${MAVEN_VERSION}" /opt/maven
