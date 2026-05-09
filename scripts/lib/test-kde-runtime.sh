echo ""
echo "=== KDE Runtime ==="
print_header

check "kde-marker" "command -v ps" "timeout 120 bash -c 'until ps -eo args= | grep -E \"(plasmashell|kwin_wayland|kwin_x11|kwin-xwayland|kded[56]?|polkit-kde-authentication-agent)\" | grep -vq grep; do sleep 2; done; echo ok'" "ok" "KDE session marker exists" 150
check "no-abc-kde" "command -v ps" "if ps -eo user=,args= | awk '\$1 == \"abc\" && \$0 ~ /(plasmashell|kwin_wayland|kwin_x11|kwin-xwayland|kded[56]?|polkit-kde-authentication-agent)/ { found=1 } END { exit found ? 1 : 0 }'; then echo ok; else ps -eo user=,pid=,args= | awk '\$1 == \"abc\" { print }'; exit 1; fi" "ok" "Critical KDE processes not abc"
