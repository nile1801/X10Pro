# XETABON X10Pro — hướng dẫn cài hai Web UI

Cập nhật: **13/11/2026**. Áp dụng cho máy kiểm chứng: LomboTech N7 / Linux 4.19.73 / `sar-Linux-v1.0alpha3`, Wi-Fi AP `192.168.169.1`. Chỉ cài khi xe đỗ, có nguồn ổn định, đã sao lưu cấu hình. **Không flash firmware, không sửa `/usr/bin/sar`.**

## 1. Phân biệt hai trang

- **Display Control**: `http://192.168.169.1:8088/` — chỉnh **màn LCD**: Red/Green/Blue gain, PWM backlight; preset lưu tại `/data/x10pro-display/display.conf`. Màu file TS không thay đổi.
- **Camera Color Lab v1.3.1**: `http://192.168.169.1:8088/camera.html` — chỉnh **đường camera TP9963 bank 0**: Saturation (0x12), Contrast (0x11), Brightness (0x10), Hue (0x13), Sharpness (0x14); cấu hình tự khởi động tại `/data/x10pro-display/camera-startup.conf`. Web UI không yêu cầu token Telnet. Hai trang có liên kết qua lại.

**Đừng nhầm LCD RGB/backlight với thông số camera.** Giao diện không cần username/password; chỉ dùng qua Wi-Fi đáng tin cậy, không mở cổng 8088 ra Internet.

**Thứ tự bắt buộc trên bản cài này:** Display Control trước, Camera Color Lab sau. **Không chạy lại installer Display Control** sau khi Color Lab đã cài vì installer Display có thể ghi đè file DHCP notify callback chứa boot hook của Camera. Máy đã chạy ổn cả hai trang thì chỉ áp dụng hotfix tương ứng, không cài lại toàn bộ.

## 2. Cài Display Control trước

1. Telnet vào camera bằng tài khoản quản trị, xác minh driver:

```sh
uname -a
cat /sys/bus/platform/devices/1602000.tcon/csc
cat /sys/class/backlight/pwm3_backlight/max_brightness
grep -n '^notify_file ' /data/wifi/udhcpd.conf
df -k /data
```

2. Cần có `notify_file /data/x10pro-display/udhcpd-notify.sh` trong DHCP config. **Nếu chưa có**, làm đúng bước kích hoạt DHCP và sao lưu cấu hình trong [README Display Control](../webui/README.md#3-kích-hoạt-tự-chạy-qua-dhcp). Không chép nguyên `udhcpd.conf` mẫu vì có thể thay IP/interface.
3. Trên máy tính, mở [`webui/install-standalone.sh`](../webui/install-standalone.sh) dạng **Raw**, copy toàn bộ script. Trong Telnet:

```sh
cat > /tmp/install-standalone.sh <<'X10PRO_INSTALL_END'
# DAN NGUYEN NOI DUNG FILE install-standalone.sh VAO DAY
X10PRO_INSTALL_END
sh -n /tmp/install-standalone.sh && sh /tmp/install-standalone.sh
```

Dòng `# DAN...` là **vị trí dán nội dung**, không phải một phần của installer. Marker kết thúc phải đứng riêng, không có dấu nháy cuối. Không chạy đồng thời `install-standalone.sh` và `install-webui.sh`: standalone đã gọi installer lõi.
4. Kết nối Wi-Fi và mở `http://192.168.169.1:8088/`; có thể `Ctrl+F5` nếu thấy trang cũ. Màu LCD đã chốt trên máy thử là Red=100%, Green=100%, Blue=50%, Backlight=100%; không áp con số này mù quáng cho thiết bị khác.

## 3. Cài/nâng cấp Camera Color Lab

**Thứ tự:** Display Control → Color Lab v1.2 → v1.3 → hotfix v1.3.1. Trên gương đã có v1.3 thì chỉ cài hotfix v1.3.1; **không cài lại v1.2**. Bản camera sử dụng helper ARM có kiểm tra hash firmware; không hoạt động bằng cách chỉ chép `camera.html`.

1. Kiểm tra trước:

```sh
sh /mnt/card/x10pro-color/controller.sh status
sh /mnt/card/x10pro-color/controller.sh preflight
sha256sum /usr/bin/sar
```

2. Với máy đã có v1.2, sử dụng gói `X10Pro_ColorLab_v1.3_30s_AutoBoot.zip`, giải nén trên máy tính, mở `x10pro_colorlab_v13/deploy_telnet.txt` và dán toàn khối vào Telnet. **Chờ `COLORLAB_1_3_INSTALLED`**. Đọc `BOOT_HOOK=...`. Với rootfs read-only thường là `wifi_dhcp_only` — không có hook native trong `/etc/init.d`.
3. Cài tiếp gói `X10Pro_ColorLab_v1.3.1_UI_State_Fix.zip` từ `deploy_telnet.txt`. Bản vá chỉ cập nhật `camera.html`, sửa dropdown và 5 slider bị trở về Original khi F5; giữ nguyên controller, CGI, profile và boot hook.
4. Nếu hotfix báo `/data only 16 KiB free (need 19 KiB temporary)`: **không xóa `/data/sar`, `/data/wifi` hoặc `camera-startup.conf`**. Sao lưu `camera.html` cũ vào thẻ SD, kiểm tra SHA rồi áp bản vá low-space như trong [hướng dẫn camera](../camera-color/README.md#hotfix-trên-data-64-kib). Tuyệt đối không bỏ kiểm tra checksum để ép ghi.
5. Mở `http://192.168.169.1:8088/camera.html?v=131`, nhấn Ctrl+F5; kiểm tra liên kết `← Display Control` và năm thanh sau F5 khớp cấu hình boot (ví dụ SAT=80 CON=70 BRI=0 HUE=0 SHARP=2).

**Nếu chưa có bộ cài v1.2:** cần lấy đủ package v1.2 có helper ARM và controller trước. Không có lệnh cài mới chỉ bằng source HTML/CGI của repo; không chạy gói v1.3 như fresh install.

## 4. Kiểm tra Test 30 giây và Auto Apply

```sh
sh /mnt/card/x10pro-color/controller.sh preflight
sh /mnt/card/x10pro-color/controller.sh status
```

Trong UI chọn preset nhẹ trước, nhấn **Test 30 giây**, chờ tự restore; rồi kiểm tra:

```sh
sh /mnt/card/x10pro-color/controller.sh report
sh /mnt/card/x10pro-color/controller.sh status
```

Kỳ vọng: `APPLIED_5_REGISTERS`, `RESTORED_5_REGISTERS`, `TRIAL_COMPLETE`, `INACTIVE`. Ghi/readback PASS không đồng nghĩa 5 hiệu ứng hình đều tăng mạnh; phải xem video TS thực tế.

Để bật tự áp sau reboot, nhấn **Lưu tự áp khi bật gương** trong Camera UI; xác minh file và reboot khi đang đỗ:

```sh
cat /data/x10pro-display/camera-startup.conf
sync
reboot
```

Telnet lại khi Wi-Fi phát, kiểm tra:

```sh
cat /tmp/x10pro-color5-boot.log
sh /mnt/card/x10pro-color/controller.sh status
sh /mnt/card/x10pro-color/controller.sh report
ls -lt /mnt/card/video_back | head -n 5
```

Máy thử 13/11/2026 đã log `BOOT_PROFILE_APPLIED` / `ACTIVE_BOOT_UNTIL_RESTORE_OR_REBOOT` với SAT=80, CON=70, BRI=0, HUE=0, SHARP=2; sau reboot vẫn tạo video TS. **Auto Apply của bản này chỉ chạy khi callback Wi-Fi/DHCP hoạt động; không bảo đảm khi Wi-Fi tắt.**

## 5. Lưu profile, giao diện F5, và khôi phục

- Slot 1–3 là profile cá nhân; chọn và lưu thì dropdown chọn đúng Slot, F5 trên **cùng browser** nhớ slot qua localStorage.
- Chọn **Lưu tự áp khi bật gương** thì boot preset nằm trên camera, F5 sẽ chọn `★ Đang lưu tự áp khi bật gương` và nạp đúng năm giá trị. Đây là **giá trị cấu hình**, không phải I²C readback tức thời.
- Test 30 giây tự restore; Apply 15 phút tự restore theo thời hạn. Boot Apply giữ màu đến khi Restore hoặc reboot.
- Muốn ngừng tự áp: Web UI → `Tắt tự áp`; nếu muốn trả màu về gốc ngay, chọn `Restore ngay`.
- Nếu không vào được Web UI, Telnet:

```sh
sh /mnt/card/x10pro-color/controller.sh restore
sh /mnt/card/x10pro-color/controller.sh boot_disable
```

Tham khảo thêm [Color Lab README](../camera-color/README.md) về restore/rollback và lưu ý an toàn.

## 6. Khắc phục sự cố

- **Không vào được port 8088:** xem `ps | grep '[h]ttpd'`, `cat /tmp/x10pro-webui-httpd.log`, `sh /data/x10pro-display/udhcpd-notify.sh`.
- **Đã lưu nhưng sau F5 vẫn Original:** mở `/camera.html?v=131`, Ctrl+F5, kiểm tra `camera-startup.conf` và SHA của `/data/x10pro-display/www/camera.html`.
- **Tắt Wi-Fi thì không Auto Apply:** giới hạn của hook `wifi_dhcp_only`, không phải khẳng định firmware/decoder lỗi.
- **Lỗi not_armed:** đang chạy bản v1.2 cũ hoặc request không đúng API; bản v1.3 không cần nhập token.
- **/data đầy (64 KiB):** chuyển các backup có xác minh sang thẻ SD, không xóa dữ liệu hệ thống. Backup nằm dưới `/mnt/card/x10pro-color/backups`.
- **Restore/readback lỗi:** dừng thử, không chạy lại liên tục; xác minh hình/video và khởi động bình thường khi cần, không ép thay thanh ghi.

**Bảo mật:** hotspot và Telnet không mã hóa, Web UI không có mật khẩu. Đừng mở 8088 ra WAN hoặc cho thiết bị không đáng tin truy cập.
