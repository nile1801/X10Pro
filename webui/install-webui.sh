#!/bin/sh
# Run as root on a compatible X10Pro, after copying this package to camera.
set -eu
SRC=${1:-/tmp/x10pro-webui-package}
BASE=/data/x10pro-display
WEB=$BASE/www
CSC=/sys/bus/platform/devices/1602000.tcon/csc
BL_DIR=/sys/class/backlight/pwm3_backlight
CONF=/data/wifi/udhcpd.conf

[ "$(id -u)" = 0 ] || { echo 'ERROR: root required' >&2; exit 1; }
[ -r "$CSC" ] && [ -w "$CSC" ] && [ -w "$BL_DIR/brightness" ] && [ -r "$BL_DIR/max_brightness" ] || {
    echo 'ERROR: incompatible LCD sysfs paths, aborting' >&2; exit 1;
}
[ -r "$CONF" ] && grep -q '^notify_file /data/x10pro-display/udhcpd-notify.sh$' "$CONF" || {
    echo 'ERROR: first install/verify the tested udhcpd notify_file hook; leaving DHCP alone.' >&2; exit 1;
}
for file in "$SRC/udhcpd-notify.sh" "$SRC/www/index.html" "$SRC/www/cgi-bin/api.cgi"; do
    [ -s "$file" ] || { echo "ERROR: missing $file" >&2; exit 1; }
done
sh -n "$SRC/udhcpd-notify.sh"
sh -n "$SRC/www/cgi-bin/api.cgi"

FREE=$(df -k /data | awk 'NR==2 {print $4}')
case "$FREE" in ''|*[!0-9]*) echo 'ERROR: df unreadable' >&2; exit 1;; esac
[ "$FREE" -ge 18 ] || { echo "ERROR: only ${FREE} KiB available on /data" >&2; exit 1; }

mkdir -p "$WEB/cgi-bin"
if [ ! -f "$BASE/udhcpd-notify.sh.pre-webui" ] && [ -f "$BASE/udhcpd-notify.sh" ]; then
    cp -p "$BASE/udhcpd-notify.sh" "$BASE/udhcpd-notify.sh.pre-webui"
fi
# Save existing driver values as initial preset; do not overwrite saved user values.
if [ ! -f "$BASE/display.conf" ]; then
    gain_pct() {
        hex=$(sed -n "s/^$1://p" "$CSC" | head -n 1)
        raw=$(printf '%d' "$hex" 2>/dev/null) || raw=4096
        printf '%s' "$(( (raw * 100 + 2048) / 4096 ))"
    }
    r=$(gain_pct r0); g=$(gain_pct g1); b=$(gain_pct b2)
    max=$(cat "$BL_DIR/max_brightness")
    actual=$(cat "$BL_DIR/brightness")
    case "$max:$actual" in *[!0-9:]*|:*) echo 'ERROR: invalid brightness' >&2; exit 1;; esac
    [ "$max" -gt 0 ] || exit 1
    light=$(( (actual * 100 + max / 2) / max ))
    for pct in "$r" "$g" "$b" "$light"; do
        [ "$pct" -ge 0 ] && [ "$pct" -le 100 ] || { echo 'ERROR: gain out of 0..100 range' >&2; exit 1; }
    done
    printf 'R=%s\nG=%s\nB=%s\nLIGHT=%s\n' "$r" "$g" "$b" "$light" > "$BASE/display.conf"
    chmod 600 "$BASE/display.conf"
fi

cp "$SRC/www/index.html" "$WEB/index.html"
cp "$SRC/www/cgi-bin/api.cgi" "$WEB/cgi-bin/api.cgi"
cp "$SRC/udhcpd-notify.sh" "$BASE/udhcpd-notify.sh"
chmod 644 "$WEB/index.html"
chmod 700 "$WEB/cgi-bin/api.cgi" "$BASE/udhcpd-notify.sh"

# No Basic Auth by request. Only this Web UI's dedicated config is modified.
# Back up any old credentials once, then clear them. Empty config = no login.
if [ -s "$BASE/httpd.conf" ] && [ ! -f "$BASE/httpd.conf.auth.bak" ]; then
    cp -p "$BASE/httpd.conf" "$BASE/httpd.conf.auth.bak"
fi
: > "$BASE/httpd.conf"
chmod 600 "$BASE/httpd.conf"

# Stop only the X10Pro Web UI listener when upgrading from an auth-enabled
# installation; other httpd instances/ports (e.g. Viidure) are left alone.
for pid in $(ps | grep '[h]ttpd' | grep '192[.]168[.]169[.]1:8088' | awk '{print $1}'); do
    kill "$pid" 2>/dev/null || true
done
sleep 1

# BusyBox httpd daemonizes without -f. If DHCP already ready, start now;
# otherwise udhcpd callback will start it after the next lease notification.
sh "$BASE/udhcpd-notify.sh"
sync
printf '\nInstalled. Wi-Fi URL: http://192.168.169.1:8088/\n'
echo 'Basic Auth: DISABLED (no username/password). Use a trusted Wi-Fi hotspot only.'
echo 'NOTE: curl without credentials should now return HTTP 200.'
echo 'Saved preset:'
cat "$BASE/display.conf"
