#!/bin/bash
# Install Azul Zulu JDK 25 headless.

set -euo pipefail

: "${JDK_PACKAGE_VERSION:?JDK_PACKAGE_VERSION is required}"

curl -fsSL https://repos.azul.com/azul-repo.key | gpg --dearmor -o /usr/share/keyrings/azul.gpg
echo "deb [signed-by=/usr/share/keyrings/azul.gpg] https://repos.azul.com/zulu/deb stable main" > /etc/apt/sources.list.d/zulu.list
apt-get update
apt-get install -y --no-install-recommends "zulu25-jdk-headless=${JDK_PACKAGE_VERSION}"
rm -rf /var/lib/apt/lists/*
rm -rf /usr/lib/jvm/*/jmods /usr/lib/jvm/*/man
