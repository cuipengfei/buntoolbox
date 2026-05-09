#!/bin/bash
# Append buntoolbox release metadata to /etc/image-release.

set -euo pipefail

cat /tmp/image-release.txt >> /etc/image-release
rm /tmp/image-release.txt
