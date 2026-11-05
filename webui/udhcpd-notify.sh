#!/bin/sh
# Invoked by udhcpd notify_file. Never touches firmware/root SquashFS.
BASE=/data/x10pro-display
CSC=/sys/bus/platform/devices/1602000.tcon/csc
BL_DIR=/sys/class/backlight/pwm3_backlight
BL=$BL_DIR/brightness
CONF=$BASE/display.conf
PREVIEW=/tmp/x10pro-preview-until
WEB=$BASE/www

valid_pct() {
    case "$1" in 0|[1-9]|[1-9][0-9]|100) return 0;; *) return 1;; esac
}
read_setting() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -n 1; }

# Start lightweight HTTP daemon after Wi-Fi/DHCP is ready; avoid duplicate.
if [ -f "$BASE/httpd.conf" ] && [ -x "$WEB/cgi-bin/api.cgi" ]; then
    if ! ps | grep '[h]ttpd' | grep -q '192.168.169.1:8088'; then
        /usr/sbin/httpd -p 192.168.169.1:8088 -h "$WEB" -c "$BASE/httpd.conf" \
            >>/tmp/x10pro-webui-httpd.log 2>&1
    fi
fi

[ -r "$CONF" ] && [ -w "$CSC" ] && [ -w "$BL" ] || exit 0
R=$(read_setting R); G=$(read_setting G)
B=$(read_setting B); LIGHT=$(read_setting LIGHT)
valid_pct "$R" && valid_pct "$G" && valid_pct "$B" && valid_pct "$LIGHT" || exit 0

# When Web UI is previewing, leave its temporary values alone for 120s.
if [ -f "$PREVIEW" ]; then
    UNTIL=$(cat "$PREVIEW" 2>/dev/null)
    NOW=$(date +%s 2>/dev/null)
    case "$UNTIL:$NOW" in *[!0-9:]*|:*) rm -f "$PREVIEW";;
        *) if [ "$NOW" -le "$UNTIL" ]; then exit 0; fi; rm -f "$PREVIEW";;
    esac
fi

max=$(cat "$BL_DIR/max_brightness" 2>/dev/null) || exit 0
case "$max" in ''|*[!0-9]*) exit 0;; esac
[ "$max" -gt 0 ] || exit 0

CHANGED=0
for pair in "r0:$R" "g1:$G" "b2:$B"; do
    key=${pair%%:*}; pct=${pair#*:}
    target=$(( (pct * 4096 + 50) / 100 ))
    expected=$(printf '0x%08x' "$target")
    current=$(sed -n "s/^$key://p" "$CSC")
    [ -n "$current" ] || exit 0
    if [ "$current" != "$expected" ]; then
        printf '%s:%s\n' "$key" "$target" > "$CSC" || exit 1
        CHANGED=1
    fi
done
TARGET_LIGHT=$(( (LIGHT * max + 50) / 100 ))
CURRENT_LIGHT=$(cat "$BL" 2>/dev/null) || exit 0
if [ "$CURRENT_LIGHT" != "$TARGET_LIGHT" ]; then
    printf '%s\n' "$TARGET_LIGHT" > "$BL" || exit 1
    CHANGED=1
fi
[ "$CHANGED" -eq 1 ] && echo "$(date) display preset reapplied" >> /tmp/x10pro-color.log
exit 0
