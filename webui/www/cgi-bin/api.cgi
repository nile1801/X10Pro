#!/bin/sh
# X10Pro LCD RGB control API. BusyBox CGI, no additional runtime.
set -f
umask 077
BASE=${X10PRO_HOME:-/data/x10pro-display}
CSC=${X10PRO_CSC:-/sys/bus/platform/devices/1602000.tcon/csc}
BL_DIR=${X10PRO_BL_DIR:-/sys/class/backlight/pwm3_backlight}
BL=$BL_DIR/brightness
CONF=$BASE/display.conf
PREVIEW=/tmp/x10pro-preview-until

reply() {
    printf 'Content-Type: application/json\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n\r\n'
    printf '%s\n' "$1"
}
fail() { reply '{"ok":false,"error":"Invalid request or driver unavailable"}'; exit 0; }
valid_pct() {
    case "$1" in 0|[1-9]|[1-9][0-9]|100) return 0;; *) return 1;; esac
}
read_setting() { sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -n 1; }
raw_gain() { sed -n "s/^$1://p" "$CSC" 2>/dev/null | head -n 1; }
gain_pct() {
    hex=$(raw_gain "$1")
    [ -n "$hex" ] || return 1
    raw=$(printf '%d' "$hex" 2>/dev/null) || return 1
    printf '%s' "$(( (raw * 100 + 2048) / 4096 ))"
}
max_brightness() {
    m=$(cat "$BL_DIR/max_brightness" 2>/dev/null) || return 1
    case "$m" in ''|*[!0-9]*) return 1;; esac
    [ "$m" -gt 0 ] || return 1
    printf '%s' "$m"
}
status() {
    [ -r "$CSC" ] && [ -r "$BL" ] || fail
    mr=$(max_brightness) || fail
    r=$(gain_pct r0) || fail
    g=$(gain_pct g1) || fail
    b=$(gain_pct b2) || fail
    raw_light=$(cat "$BL" 2>/dev/null) || fail
    case "$raw_light" in ''|*[!0-9]*) fail;; esac
    light=$(( (raw_light * 100 + mr / 2) / mr ))
    sr=$(read_setting R); sg=$(read_setting G)
    sb=$(read_setting B); sl=$(read_setting LIGHT)
    valid_pct "$sr" || sr=$r
    valid_pct "$sg" || sg=$g
    valid_pct "$sb" || sb=$b
    valid_pct "$sl" || sl=$light
    reply "{\"ok\":true,\"r\":$r,\"g\":$g,\"b\":$b,\"light\":$light,\"saved\":{\"r\":$sr,\"g\":$sg,\"b\":$sb,\"light\":$sl}}"
}

case "${REQUEST_METHOD:-GET}" in
    GET) status; exit 0;;
    POST) ;;
    *) fail;;
esac
case "${CONTENT_TYPE:-}" in application/x-www-form-urlencoded*) ;; *) fail;; esac
case "${CONTENT_LENGTH:-}" in ''|*[!0-9]*) fail;; esac
[ "$CONTENT_LENGTH" -ge 1 ] && [ "$CONTENT_LENGTH" -le 110 ] || fail
BODY=$(dd bs=1 count="$CONTENT_LENGTH" 2>/dev/null) || fail

R= G= B= LIGHT= MODE=
IFS='&'
for pair in $BODY; do
    key=${pair%%=*}
    value=${pair#*=}
    case "$key" in
        r) R=$value;;
        g) G=$value;;
        b) B=$value;;
        light) LIGHT=$value;;
        mode) MODE=$value;;
        *) fail;;
    esac
done
unset IFS
valid_pct "$R" && valid_pct "$G" && valid_pct "$B" && valid_pct "$LIGHT" || fail
case "$MODE" in preview|save) ;; *) fail;; esac
[ -w "$CSC" ] && [ -w "$BL" ] || fail
MR=$(max_brightness) || fail

# Prevent DHCP callback from overriding user preview while dragging sliders.
NOW=$(date +%s 2>/dev/null) || fail
case "$NOW" in ''|*[!0-9]*) fail;; esac
printf '%s\n' "$(( NOW + 120 ))" > "$PREVIEW" || fail

# Apply all CSC diagonal gains; off-diagonal entries remain unchanged.
printf 'r0:%s\n' "$(( (R * 4096 + 50) / 100 ))" > "$CSC" || fail
printf 'g1:%s\n' "$(( (G * 4096 + 50) / 100 ))" > "$CSC" || fail
printf 'b2:%s\n' "$(( (B * 4096 + 50) / 100 ))" > "$CSC" || fail
printf '%s\n' "$(( (LIGHT * MR + 50) / 100 ))" > "$BL" || fail

if [ "$MODE" = save ]; then
    tmp="$CONF.tmp.$$"
    printf 'R=%s\nG=%s\nB=%s\nLIGHT=%s\n' "$R" "$G" "$B" "$LIGHT" > "$tmp" || fail
    mv -f "$tmp" "$CONF" || fail
    rm -f "$PREVIEW"
fi
status
