#!/bin/bash
# Install Gradle.

set -euo pipefail

: "${GRADLE_VERSION:?GRADLE_VERSION is required}"

curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle.zip
unzip -q /tmp/gradle.zip -d /opt
ln -sf "/opt/gradle-${GRADLE_VERSION}" /opt/gradle
rm /tmp/gradle.zip
