#!/bin/sh
# X10Pro LCD color/backlight auto-apply via BusyBox udhcpd notify_file.
# Tested: LomboTech N7, Linux 4.19.73, sar-Linux-v1.0alpha3.
# Only changes LCD TCON CSC blue gain and PWM backlight, not recorded MP4.

# ===== USER SETTINGS (integer percentages 0..100) =====
BLUE_LEVEL=50
BACKLIGHT_LEVEL=100
# =====================================================

CSC=/sys/bus/platform/devices/1602000.tcon/csc
BL_DIR=/sys/class/backlight/pwm3_backlight
BL="$BL_DIR/brightness"
LOG=/tmp/x10pro-color.log

# Plain decimal 0..100 without leading zeroes.
case "$BLUE_LEVEL" in
    0|[1-9]|[1-9][0-9]|100) ;;
    *) exit 1 ;;
esac
case "$BACKLIGHT_LEVEL" in
    0|[1-9]|[1-9][0-9]|100) ;;
    *) exit 1 ;;
esac

[ -r "$CSC" ] && [ -w "$CSC" ] || exit 0
[ -r "$BL" ] && [ -w "$BL" ] || exit 0
[ -r "$BL_DIR/max_brightness" ] || exit 0

MAX_BL=$(cat "$BL_DIR/max_brightness" 2>/dev/null) || exit 1
case "$MAX_BL" in
    ''|*[!0-9]*) exit 1 ;;
esac
[ "$MAX_BL" -gt 0 ] || exit 1

# TCON Q12 matrix coefficient: 4096 = 100%.
TARGET_BLUE=$(( (BLUE_LEVEL * 4096 + 50) / 100 ))
TARGET_BLUE_HEX=$(printf '0x%08x' "$TARGET_BLUE")
TARGET_BL=$(( (BACKLIGHT_LEVEL * MAX_BL + 50) / 100 ))

CURRENT_BLUE=$(sed -n 's/^b2://p' "$CSC")
CURRENT_BL=$(cat "$BL" 2>/dev/null) || exit 1
[ -n "$CURRENT_BLUE" ] || exit 0

CHANGED=0
if [ "$CURRENT_BLUE" != "$TARGET_BLUE_HEX" ]; then
    printf 'b2:%s\n' "$TARGET_BLUE" > "$CSC" || exit 1
    CHANGED=1
fi
if [ "$CURRENT_BL" != "$TARGET_BL" ]; then
    printf '%s\n' "$TARGET_BL" > "$BL" || exit 1
    CHANGED=1
fi

if [ "$CHANGED" -eq 1 ]; then
    echo "$(date) Blue=$BLUE_LEVEL% b2=$TARGET_BLUE Backlight=$TARGET_BL/$MAX_BL" >> "$LOG"
fi
exit 0
