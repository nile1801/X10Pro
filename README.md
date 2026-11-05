# X10Pro LCD Color & Backlight — No-Flash Auto-Apply

Tự chỉnh **Blue Gain** và độ sáng màn hình gương XETABON X10Pro mà **không cần flash firmware**, bằng BusyBox DHCP callback (notify_file).

## Thiết bị đã kiểm chứng

- XETABON X10Pro, Linux Virgo 4.19.73, LomboTech N7, ứng dụng sar
- Firmware được thử: 20251103.180135 / sar-Linux-v1.0alpha3
- TCON CSC: /sys/bus/platform/devices/1602000.tcon/csc
- Backlight: /sys/class/backlight/pwm3_backlight/brightness
- DHCP server: BusyBox udhcpd, cấu hình tại /data/wifi/udhcpd.conf
- Root filesystem SquashFS chỉ đọc; /data là JFFS2 ghi được.

**Không cam kết chạy trên X10Pro khác revision hoặc các camera khác.** Phải xác minh đủ các đường dẫn và DHCP callback trước khi áp dụng. Không có firmware nào được flash bởi cách này.

## File trong repo

1. **udhcpd-notify.sh** — file thực thi theo chu kỳ DHCP; đặt tại /data/x10pro-display/udhcpd-notify.sh. Tự tính Blue từ BLUE_LEVEL nguyên (0–100%), đọc lại giá trị hiện tại và chỉ ghi CSC/backlight khi lệch.
2. **udhcpd.conf** — mẫu cấu hình đầy đủ của một máy đã chạy thành công. **Không ghi đè nguyên file trên máy có cấu hình IP khác**; chỉ hợp nhất ba dòng cấu hình ở cuối.
3. **README.md** — tài liệu này.

## Cấu hình mặc định đã chốt

| Giá trị | Thiết lập |
|---|---|
| Red Gain / Green Gain | Không thay đổi (100%) |
| BLUE_LEVEL | 50 (%) → b2 = 2048 = 0x00000800 |
| BACKLIGHT_LEVEL | 100 (%) → brightness bằng max_brightness (100 trên máy đã thử) |
| auto_time | 5 giây |
| lease_file | /tmp/udhcpd-x10pro.leases |
| Log tạm | /tmp/x10pro-color.log |

Cách tính Blue: round(BLUE_LEVEL * 4096 / 100), chỉ ghi hệ số đường chéo b2 của TCON. Không thay đổi camera ISP hoặc dữ liệu MP4. Backlight là độ sáng PWM, không phải digital contrast.

## Cài đặt qua Telnet (không rút thẻ, không flash)

Kết nối vào hotspot X10Pro; mặc định ở máy đã thử: 192.168.169.1. Vào Telnet với tài khoản quản trị thiết bị. **Không đăng công khai mật khẩu Telnet hoặc mật khẩu hotspot.** Chỉ thao tác khi xe đỗ, không cần ghi hình quan trọng.

### 1. Kiểm tra đúng phần cứng

~~~sh
uname -a
cat /proc/cpuinfo | grep Hardware
cat /sys/bus/platform/devices/1602000.tcon/csc
cat /sys/class/backlight/pwm3_backlight/max_brightness
command -v udhcpd
busybox --list | grep '^udhcpd$'
~~~

Nếu không có TCON CSC hoặc backlight như trên, dừng, không cài.

### 2. Tạo callback

Trên máy đang có file callback từ lần cài cũ, chỉ cần **thay nội dung** bằng file udhcpd-notify.sh trong repo. Để thao tác từ Telnet mà không tháo thẻ, mở nội dung file trên máy tính, dán qua here-document:

~~~sh
mkdir -p /data/x10pro-display
cp -p /data/x10pro-display/udhcpd-notify.sh \
  /data/x10pro-display/udhcpd-notify.sh.bak 2>/dev/null || true

cat > /data/x10pro-display/udhcpd-notify.sh <<'EOF'
# Dán toàn bộ nội dung file udhcpd-notify.sh tại đây, không dán dòng chú thích này.
EOF

chmod 700 /data/x10pro-display/udhcpd-notify.sh
sh -n /data/x10pro-display/udhcpd-notify.sh
~~~

**Lưu ý:** Khối here-document ở trên là khung thao tác, chưa tự chứa code callback; bắt buộc thay dòng chú thích bằng toàn bộ file từ GitHub. Không chạy callback rỗng.

Hoặc tải file từ GitHub trên laptop, rồi dùng cách truyền file tin cậy của anh để đặt đúng vị trí trên camera. Camera phát AP thường không có Internet nên không mặc định chạy wget từ GitHub trực tiếp trên camera.

### 3. Kích hoạt tự chạy qua DHCP

Sao lưu cấu hình DHCP gốc trước khi chỉnh:

~~~sh
CONF=/data/wifi/udhcpd.conf
mkdir -p /data/x10pro-display
if [ ! -f /data/x10pro-display/udhcpd.conf.original ]; then
    cp -p "$CONF" /data/x10pro-display/udhcpd.conf.original
fi

# Xóa bản cũ của 3 directive, giữ nguyên các thiết lập IP/SSID hiện có.
sed -i '/^[[:space:]]*auto_time[[:space:]]/d; /^[[:space:]]*lease_file[[:space:]]/d; /^[[:space:]]*notify_file[[:space:]]/d' "$CONF"

cat >> "$CONF" <<'EOF'
auto_time 5
lease_file /tmp/udhcpd-x10pro.leases
notify_file /data/x10pro-display/udhcpd-notify.sh
EOF

sync
grep -E '^(auto_time|lease_file|notify_file)' "$CONF"
~~~

Mẫu udhcpd.conf trong repo dùng IP 192.168.169.1 và interface wlan0; **không cần ghi đè nguyên file** nếu máy đã có DHCP hoạt động. Thao tác chỉ sửa cấu hình tại /data, không sửa /etc/init.d, kernel hoặc flash.

### 4. Kiểm tra trực tiếp và reboot

~~~sh
sh -n /data/x10pro-display/udhcpd-notify.sh
sh /data/x10pro-display/udhcpd-notify.sh
grep '^b2:' /sys/bus/platform/devices/1602000.tcon/csc
cat /sys/class/backlight/pwm3_backlight/brightness
~~~

Kỳ vọng b2:0x00000800 và brightness 100 (khi max_brightness là 100).

Reboot khi máy không cần ghi hình:

~~~sh
sync
reboot
~~~

Sau reboot, Telnet lại và kiểm tra:

~~~sh
cat /tmp/x10pro-color.log 2>/dev/null
grep '^b2:' /sys/bus/platform/devices/1602000.tcon/csc
cat /sys/class/backlight/pwm3_backlight/brightness
ps | grep '[u]dhcpd'
~~~

Đã kiểm chứng trên một máy: log có "color applied", b2=0x00000800, brightness=100 và udhcpd vẫn hoạt động sau reboot.

## Đổi mức Blue và Backlight

Mở /data/x10pro-display/udhcpd-notify.sh (ví dụ vi hoặc sửa qua here-document) rồi thay:

~~~sh
BLUE_LEVEL=50
BACKLIGHT_LEVEL=100
~~~

Hai biến nhận **số nguyên 0..100, không thêm dấu % và không viết số có số 0 ở đầu**. Ví dụ BLUE_LEVEL=65 cho b2 ≈ 2662; BACKLIGHT_LEVEL=80 cho 80% mức max_brightness.

Callback được gọi theo hoạt động lưu lease của udhcpd, không bảo đảm đúng 5 giây kể từ lúc cấp nguồn. Nếu driver/ứng dụng đã đặt đúng giá trị, script không ghi lại. File log ở /tmp không giữ sau reboot. Cấu hình này chỉ chạy khi udhcpd của hotspot đang hoạt động.

**Quan trọng:** Nếu firmware tự tắt Wi-Fi hotspot khi không có phiên Viidure, udhcpd có thể bị dừng và callback cũng ngừng. Cấu hình này **không giải quyết lỗi hotspot tự tắt**. Để xử lý chuyện đó cần nghiên cứu riêng chính sách phiên Wi-Fi/heartbeat trong sar.

## Khôi phục về mặc định / gỡ cài đặt

Khi vẫn còn Telnet, phục hồi cấu hình DHCP gốc:

~~~sh
if [ -f /data/x10pro-display/udhcpd.conf.original ]; then
    cp -p /data/x10pro-display/udhcpd.conf.original /data/wifi/udhcpd.conf
    sync
fi
~~~

Để trả màu runtime về mặc định cho **máy đã thử**:

~~~sh
printf 'b2:4096\n' > /sys/bus/platform/devices/1602000.tcon/csc
printf '85\n' > /sys/class/backlight/pwm3_backlight/brightness
~~~

Ở các máy khác, giá trị brightness gốc có thể khác 85; phải ghi nhận trước khi chỉnh. Reboot để nạp lại DHCP config gốc. Không xóa bản sao lưu trước khi xác minh Wi-Fi/Telnet hoạt động trở lại.

Nếu Wi-Fi vẫn phát sóng nhưng không cấp DHCP sau khi sửa cấu hình, có thể thử IP tĩnh thích hợp với mạng đang được camera phát, rồi Telnet vào sửa lại cấu hình. Điều này không giúp được nếu AP hoàn toàn tắt.

## Giới hạn và an toàn

- Cần quyền root; Telnet không mã hóa nên chỉ dùng trên mạng camera tin cậy và cân nhắc tắt khi không cần.
- Chỉ kiểm chứng với một phần cứng/firmware nêu trên.
- Chỉnh sai CSC có thể làm hình mất màu; backlight 100% có thể tăng nhiệt/điện năng.
- Callback DHCP mỗi 5 giây có thêm chi phí CPU nhỏ; lease lưu tại /tmp để tránh ghi JFFS2 liên tục.
- Cấu hình DHCP sai có thể làm mất khả năng truy cập camera qua Wi-Fi. Luôn sao lưu trước, đừng ghi đè IP/interface gốc.
- Không đưa firmware dump, mật khẩu hay dữ liệu định danh cá nhân vào repository công khai.

## Nguyên lý

BusyBox udhcpd nạp cấu hình nằm trên /data khi hotspot khởi chạy. Với auto_time và notify_file, sau mỗi đợt ghi lease, udhcpd gọi callback. Callback tự tính Blue Q12 và giá trị backlight rồi chỉ ghi nếu khác mục tiêu. Đây là boot hook gián tiếp thông qua DHCP, không phải patch firmware; khi Wi-Fi/DHCP tắt, không còn điểm kích hoạt.
