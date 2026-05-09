echo ""
echo "=== i3 Runtime ==="
print_header

check "whoami" "whoami" "whoami" "root" "Interactive user is root"
check "HOME" "printf '%s\n' \"$HOME\"" "test \"$HOME\" = /root && echo /root" "/root" "HOME is /root"

check "webtop-3200" "command -v curl" "timeout 120 bash -c 'until curl -fsS http://127.0.0.1:3200/ >/tmp/webtop-3200.out; do sleep 2; done; test -s /tmp/webtop-3200.out && echo ok'" "ok" "Webtop HTTP responds on 3200" 150
check "webtop-3000" "command -v ss" "if ss -tln | awk '{print \$4}' | grep -Eq '(^|:)3000$'; then echo occupied; exit 1; else echo free; fi" "free" "Webtop does not listen on 3000"
check "openvscode" "command -v openvscode-start" "timeout 120 bash -c 'openvscode-start >/tmp/openvscode-start.log 2>&1 & pid=\$!; trap \"kill \$pid 2>/dev/null || true\" EXIT; until curl -fsS http://127.0.0.1:3000/ >/tmp/openvscode-3000.out; do sleep 2; done; test -s /tmp/openvscode-3000.out && echo ok'" "ok" "OpenVSCode serves on 3000" 150

check "no-abc-gui" "command -v ps" "if ps -eo user=,comm= | awk '\$1 == \"abc\" && \$2 ~ /^(Xvfb|i3|i3bar|selkies|dbus-daemon|pulseaudio|pipewire|nginx)$/ { found=1 } END { exit found ? 1 : 0 }'; then echo ok; else ps -eo user=,pid=,comm= | awk '\$1 == \"abc\" { print }'; exit 1; fi" "ok" "Critical GUI processes not abc"

echo ""
echo "=========================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "BUNTOOLBOX_TESTS_COMPLETED"
echo "=========================================="

[ $FAILED -eq 0 ]
