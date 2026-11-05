#!/bin/sh
# Standalone installer: paste entire file into X10Pro Telnet shell as root.
set -e
PKG=/tmp/x10pro-webui-package
mkdir -p "$PKG/www/cgi-bin"
cat > "$PKG/udhcpd-notify.sh" <<'X10PRO_EMBED_0_END'
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
X10PRO_EMBED_0_END
cat > "$PKG/www/index.html" <<'X10PRO_EMBED_1_END'
<!doctype html>
<html lang="vi">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>X10Pro Display Control</title>
<style>
:root{color-scheme:dark;font-family:system-ui,-apple-system,Arial,sans-serif;background:#0d121b;color:#eaf0fa}
*{box-sizing:border-box}body{max-width:580px;margin:0 auto;padding:20px 16px 50px}
h1{font-size:24px;margin:0 0 5px}small,.sub{color:#97a5ba}.sub{font-size:13px;margin-bottom:24px}
.card{background:#161f2e;border:1px solid #28374b;border-radius:17px;padding:20px;margin:14px 0}
.row{display:flex;justify-content:space-between;align-items:center;gap:8px}
.row strong{font-variant-numeric:tabular-nums}h2{font-size:14px;margin:0 0 14px;color:#b2c1d7}
.group{margin:20px 0}.group:first-child{margin-top:6px}
input[type=range]{width:100%;accent-color:var(--accent,#719fff);cursor:pointer;margin:12px 0 2px}
.preview{height:105px;border-radius:12px;border:1px solid #455161;background:rgb(255,255,128);box-shadow:inset 0 0 45px #0003}
.actions{display:flex;gap:10px;margin-top:14px;flex-wrap:wrap}
button{border:1px solid #34465c;border-radius:11px;padding:12px 16px;font-size:15px;font-weight:650;cursor:pointer;background:#253349;color:#eaf0fa;flex:1}
button.primary{background:#4182f2;border-color:#4182f2;color:#fff}button:disabled{opacity:.5;cursor:not-allowed}
#msg{font-size:13px;color:#a9bdd4;min-height:20px;margin-top:13px}
.chip{font-size:11px;display:inline-block;border-radius:40px;padding:4px 9px;background:#23334a;color:#b6c9e4}
.note{font-size:12px;line-height:1.55;color:#93a4be}
</style>
</head>
<body>
<header class="row"><div><h1>X10Pro Display Control</h1><div class="sub">LCD TCON · RGB Gain · Backlight</div></div><span class="chip" id="connect">Connecting</span></header>
<div class="card">
  <h2>RGB color balance</h2>
  <div class="group" style="--accent:#f26e79"><div class="row"><label for="r">Red Gain</label><strong id="rv">100%</strong></div><input id="r" type="range" min="0" max="100" value="100"></div>
  <div class="group" style="--accent:#5bd2a5"><div class="row"><label for="g">Green Gain</label><strong id="gv">100%</strong></div><input id="g" type="range" min="0" max="100" value="100"></div>
  <div class="group" style="--accent:#629efc"><div class="row"><label for="b">Blue Gain</label><strong id="bv">50%</strong></div><input id="b" type="range" min="0" max="100" value="50"></div>
</div>
<div class="card"><h2>Screen backlight</h2><div class="group" style="--accent:#f2c563"><div class="row"><label for="light">Brightness</label><strong id="lightv">100%</strong></div><input id="light" type="range" min="0" max="100" value="100"></div></div>
<div class="card"><h2>Color preview (approximate)</h2><div class="preview" id="preview"></div><p class="note">Changes are sent to the LCD while dragging. Preview expires after 120 seconds unless saved. Preview is not the actual camera image.</p>
<div class="actions"><button id="restore">Original RGB</button><button class="primary" id="save">Save to camera</button></div><div id="msg">Loading camera settings…</div></div>
<p class="note">HTTP works only on the camera hotspot. Credentials travel over unencrypted local HTTP. Do not expose port 8088 to other networks. Saving writes a tiny preset to /data.</p>
<script>
(()=>{
const ids=['r','g','b','light'];const el=id=>document.getElementById(id);
let busy=false,queued=false,debounce=null,initialized=false,saving=false;
function values(){return Object.fromEntries(ids.map(k=>[k,Number(el(k).value)]));}
function draw(){const v=values();ids.forEach(k=>el(k+'v').textContent=v[k]+'%');el('preview').style.background=`rgb(${Math.round(255*v.r/100)},${Math.round(255*v.g/100)},${Math.round(255*v.b/100)})`;el('preview').style.opacity=Math.max(.12,v.light/100);}
function message(s){el('msg').textContent=s;}
async function call(mode){const params=new URLSearchParams({...values(),mode});const ctl=new AbortController();const timeout=setTimeout(()=>ctl.abort(),4000);
try{const resp=await fetch('/cgi-bin/api.cgi',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:params.toString(),signal:ctl.signal,cache:'no-store'});if(!resp.ok)throw Error('HTTP '+resp.status);const j=await resp.json();if(!j.ok)throw Error(j.error||'API error');return j;}finally{clearTimeout(timeout);}}
async function preview(){if(busy){queued=true;return;}busy=true;try{await call('preview');el('connect').textContent='Connected';message('Preview applied. Press Save to keep after reboot.');}catch(e){el('connect').textContent='Error';message('Preview failed: '+e.message);}finally{busy=false;if(queued){queued=false;preview();}}}
function schedule(){draw();if(!initialized||saving)return;clearTimeout(debounce);debounce=setTimeout(preview,230);}
ids.forEach(k=>el(k).addEventListener('input',schedule));
el('restore').addEventListener('click',()=>{el('r').value=100;el('g').value=100;el('b').value=100;el('light').value=85;schedule();message('Factory-like preview. Press Save if you want to keep it.');});
el('save').addEventListener('click',async()=>{clearTimeout(debounce);saving=true;el('save').disabled=true;try{await call('save');el('connect').textContent='Saved';message('Saved to /data. The DHCP callback will restore it after reboot.');}catch(e){message('Save failed: '+e.message);}finally{saving=false;el('save').disabled=false;}});
(async()=>{try{const resp=await fetch('/cgi-bin/api.cgi',{cache:'no-store'});if(!resp.ok)throw Error('HTTP '+resp.status);const j=await resp.json();if(!j.ok)throw Error(j.error||'Read failed');for(const k of ids)el(k).value=j[k];draw();initialized=true;el('connect').textContent='Connected';message('Loaded current LCD values. Saved Blue: '+j.saved.b+'%');}catch(e){el('connect').textContent='Offline';message('Cannot read camera: '+e.message);}})();
})();
</script>
</body>
</html>
X10PRO_EMBED_1_END
cat > "$PKG/www/cgi-bin/api.cgi" <<'X10PRO_EMBED_2_END'
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
X10PRO_EMBED_2_END
cat > "$PKG/install-webui.sh" <<'X10PRO_EMBED_3_END'
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

# Generate an initial password locally. Never put the credential in GitHub.
if [ ! -f "$BASE/httpd.conf" ]; then
    command -v od >/dev/null || { echo 'ERROR: od missing; cannot generate web password' >&2; exit 1; }
    command -v tr >/dev/null || { echo 'ERROR: tr missing; cannot generate web password' >&2; exit 1; }
    PASS=$(dd if=/dev/urandom bs=12 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')
    [ "${#PASS}" = 24 ] || { echo 'ERROR: random password generation failed' >&2; exit 1; }
    printf '/:admin:%s\n' "$PASS" > "$BASE/httpd.conf"
    chmod 600 "$BASE/httpd.conf"
    echo "WEB USER: admin"
    echo "WEB PASSWORD: $PASS"
else
    echo 'Existing web password preserved in /data/x10pro-display/httpd.conf'
fi

# BusyBox httpd daemonizes without -f. If DHCP already ready, start now;
# otherwise udhcpd callback will start it after the next lease notification.
sh "$BASE/udhcpd-notify.sh"
sync
printf '\nInstalled. Wi-Fi URL: http://192.168.169.1:8088/\n'
echo 'NOTE: Verify curl without credentials returns HTTP 401 before using the write API.'
echo 'Saved preset:'
cat "$BASE/display.conf"
X10PRO_EMBED_3_END
sh "$PKG/install-webui.sh" "$PKG"