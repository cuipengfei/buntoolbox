echo ""
echo "=== Webtop Runtime ==="
print_header

check "whoami" "whoami" "whoami" "root" "Interactive user is root"
check "HOME" "printf '%s\n' \"$HOME\"" "test \"$HOME\" = /root && echo /root" "/root" "HOME is /root"

check "webtop-3200" "command -v curl" "timeout 120 bash -c 'until curl -fsS http://127.0.0.1:3200/ >/tmp/webtop-3200.out; do sleep 2; done; test -s /tmp/webtop-3200.out && echo ok'" "ok" "Webtop HTTP responds on 3200" 150

check "no-abc-webtop" "command -v ps" "if ps -eo user=,args= | awk '\$1 == \"abc\" && \$0 ~ /(Xvfb|Xwayland|selkies|dbus-daemon|pulseaudio|pipewire|nginx)/ { found=1 } END { exit found ? 1 : 0 }'; then echo ok; else ps -eo user=,pid=,args= | awk '\$1 == \"abc\" { print }'; exit 1; fi" "ok" "Critical Webtop support processes not abc"
