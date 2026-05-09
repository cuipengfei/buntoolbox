echo ""
echo "=== i3 Runtime ==="
print_header

check "i3-marker" "command -v ps" "timeout 120 bash -c 'until ps -eo comm= | grep -Eq \"^(i3|i3bar)$\"; do sleep 2; done; echo ok'" "ok" "i3 session marker exists" 150
check "no-abc-i3" "command -v ps" "if ps -eo user=,comm= | awk '\$1 == \"abc\" && \$2 ~ /^(i3|i3bar)$/ { found=1 } END { exit found ? 1 : 0 }'; then echo ok; else ps -eo user=,pid=,comm= | awk '\$1 == \"abc\" { print }'; exit 1; fi" "ok" "Critical i3 processes not abc"
