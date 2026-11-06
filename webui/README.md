# X10Pro RGB Web UI — hướng dẫn đầy đủ (không flash)

Web UI điều chỉnh **Red / Green / Blue / LCD Backlight** của X10Pro LomboTech N7 ngay trên trình duyệt bằng BusyBox `httpd` + CGI shell, không cần PHP/Node.js, không cần Viidure để chỉnh màu.

**Địa chỉ:** http://192.168.169.1:8088/  
**Xác thực:** **Không có Basic Auth**; mở web là sử dụng được. Chỉ dùng trên hotspot X10Pro đáng tin cậy, không mở port 8088 ra Internet.

> Đã thử trên phần cứng: HTTP trang tĩnh và CGI trả `X10PRO_STATIC_OK` / `X10PRO_CGI_OK`. Quy trình cài đặt và việc viết R/G chưa được xác nhận trên thiết bị thật sau phiên bản mã nguồn này.

## 1. Hai installer khác nhau ở đâu?

| File | Chức năng | Có cần chạy cả hai? |
| --- | --- | --- |
| [`install-standalone.sh`](./install-standalone.sh) | **Bộ cài trọn gói một file**: chứa `index.html`, `api.cgi`, callback DHCP và `install-webui.sh`. Khi chạy, tự bung vào `/tmp` rồi gọi `install-webui.sh`. | **Không. Dùng file này là đủ**, khuyên dùng khi Telnet. |
| [`install-webui.sh`](./install-webui.sh) | Bộ cài lõi: kiểm tra môi trường, sao lưu callback cũ, chép các file từ thư mục package và bật HTTP server. | Chỉ chạy riêng nếu đã chép đầy đủ thư mục package vào `/tmp/x10pro-webui-package`. |

`install-standalone.sh` **không cài một Web UI khác**; nó đóng gói và gọi đúng `install-webui.sh`. Không chạy riêng cả hai; chạy lần hai chỉ là cài/nâng cấp lại.

Các mã nguồn khác:
- [`udhcpd-notify.sh`](./udhcpd-notify.sh): hook DHCP mở Web UI sau boot và áp preset LCD đã lưu.
- [`www/index.html`](./www/index.html): trang giao diện kéo slider.
- [`www/cgi-bin/api.cgi`](./www/cgi-bin/api.cgi): CGI đọc/ghi trực tiếp TCON/backlight.

## 2. Điều kiện trước khi cài

- Root Telnet vào camera; X10Pro thử nghiệm dùng IP `192.168.169.1`.
- Có BusyBox `httpd` hỗ trợ CGI; đã được chứng minh trên máy thử nghiệm.
- Tồn tại các driver: `/sys/bus/platform/devices/1602000.tcon/csc`, `/sys/class/backlight/pwm3_backlight/{brightness,max_brightness}`.
- **Đã cài DHCP callback từ bản Blue Gain trước**: `/data/wifi/udhcpd.conf` phải có dòng `notify_file /data/x10pro-display/udhcpd-notify.sh`. Nếu mới cài từ đầu, làm trước [phần cài hook DHCP ở README gốc](../README.md#3-kích-hoạt-tự-chạy-qua-dhcp). Installer Web UI **không tự thay đổi DHCP config**.
- Phân vùng `/data` nhỏ (máy thử 64 KiB), giữ dung lượng trống. Installer sẽ từ chối khi còn ít hơn 18 KiB.

Kiểm tra từ Telnet trước:

```sh
uname -a
grep '^notify_file ' /data/wifi/udhcpd.conf
cat /sys/bus/platform/devices/1602000.tcon/csc
cat /sys/class/backlight/pwm3_backlight/max_brightness
df -h /data
```

**Nếu thiếu hoặc khác đường dẫn, dừng lại.** Không áp dụng cho mọi model X10Pro hoặc camera khác.

## 3. Cài đặt khuyên dùng: một file qua Telnet

1. Mở [`install-standalone.sh`](./install-standalone.sh) trên laptop, nhấn **Raw**, copy toàn bộ nội dung script.
2. Trong cửa sổ **Telnet của camera**, gõ dòng sau và nhấn Enter:

   ```sh
   cat > /tmp/install-standalone.sh <<'X10PRO_INSTALL_END'
   ```

3. Dán **toàn bộ nội dung** vừa copy. Sau khi paste xong, nhập dòng này **riêng một dòng**:

   ```sh
   X10PRO_INSTALL_END
   ```

4. Kiểm tra cú pháp rồi chạy:

   ```sh
   sh -n /tmp/install-standalone.sh && sh /tmp/install-standalone.sh
   ```

5. Installer sẽ tạo các file dưới `/data/x10pro-display/`, lưu preset RGB hiện tại lần đầu, **xóa Basic Auth** trong file cấu hình HTTP riêng của Web UI (sao lưu nội dung cũ thành `httpd.conf.auth.bak` nếu có), khởi động lại **chỉ** server cổng 8088, và gọi callback DHCP.

   Không cài PHP/Node.js, không flash firmware, không sửa SquashFS hoặc kernel. Không cần tự chạy `install-webui.sh` nữa.

6. Trên laptop/điện thoại kết nối hotspot camera, truy cập:

   **http://192.168.169.1:8088/**

Nếu HTTP server chưa lên, vào Telnet chạy:

```sh
sh /data/x10pro-display/udhcpd-notify.sh
ps | grep '[h]ttpd'
cat /tmp/x10pro-webui-httpd.log 2>/dev/null
```

Do chương trình dựa vào DHCP/Wi-Fi để tự khởi động, **Wi-Fi tự tắt thì không vào được Web UI**. Bản mod không giải quyết lỗi Wi-Fi tự tắt.

### Trường hợp muốn cài bằng `install-webui.sh` riêng

Cần chép đầy đủ và đúng cấu trúc file lên camera:

```text
/tmp/x10pro-webui-package/
├── install-webui.sh
├── udhcpd-notify.sh
└── www/
    ├── index.html
    └── cgi-bin/
        └── api.cgi
```

Sau đó chạy:

```sh
sh /tmp/x10pro-webui-package/install-webui.sh /tmp/x10pro-webui-package
```

Nếu chỉ copy `install-webui.sh` mà không copy ba file còn lại, installer **sẽ báo thiếu file**. Vì vậy anh chỉ cần dùng `install-standalone.sh` cho đơn giản.

## 4. Cách dùng

1. Kết nối hotspot X10Pro, mở `http://192.168.169.1:8088/` — **không yêu cầu username/password**.
2. Di chuyển từng thanh **Red, Green, Blue** và **Brightness** (số nguyên 0–100%). Thao tác gửi lệnh CGI để **preview trực tiếp trên LCD**, không phải chỉnh màu video ghi.
3. Nút **Original RGB** đặt RGB về 100% và backlight khoảng 85% (tham khảo máy thử); đây là mức mặc định tham khảo, không phải phục hồi cấu hình firmware tự động.
4. Nút **Save to camera** ghi preset vào `/data/x10pro-display/display.conf`. Khi reboot, callback DHCP đọc preset này và áp lại.
5. Nếu không Save, preview hết hạn sau khoảng **120 giây**; khi callback chạy, cấu hình đã lưu sẽ được phục hồi.

Khuyến nghị: khi thử R/G lần đầu, chỉ giảm nhẹ khoảng 5–10%, không kéo ngay về 0. Driver R/G tồn tại nhưng chưa được kiểm chứng bằng thử nghiệm trên phần cứng thật.

## 5. Kiểm tra sau cài và sau reboot

Trong **PowerShell laptop**:

```powershell
curl.exe -i --connect-timeout 3 --max-time 8 http://192.168.169.1:8088/
curl.exe --connect-timeout 3 --max-time 8 http://192.168.169.1:8088/cgi-bin/api.cgi
```

Mong đợi:
- Trang HTML trả **HTTP 200** (không còn `401 Unauthorized`).
- CGI trả JSON có `"ok":true` cùng các giá trị RGB/backlight.

Trong **Telnet camera**:

```sh
ps | grep '[h]ttpd'
cat /data/x10pro-display/display.conf
cat /sys/bus/platform/devices/1602000.tcon/csc
cat /sys/class/backlight/pwm3_backlight/brightness
cat /tmp/x10pro-webui-httpd.log 2>/dev/null
```

Nếu browser vẫn hiện hộp thoại Basic Auth sau khi nâng cấp, đóng tab cũ (hoặc mở cửa sổ ẩn danh), kiểm tra HTTP trả 200 và cài lại bản script mới cho đúng.

## 6. Đã cài bản Basic Auth cũ: bỏ đăng nhập, không cần cài lại

Nếu anh **đã có Web UI hoạt động**, chỉ cần làm một lần trong Telnet:

```sh
BASE=/data/x10pro-display
[ -f "$BASE/httpd.conf" ] || { echo "Missing httpd.conf"; exit 1; }
[ -s "$BASE/httpd.conf" ] && [ ! -f "$BASE/httpd.conf.auth.bak" ] && \
    cp -p "$BASE/httpd.conf" "$BASE/httpd.conf.auth.bak"

: > "$BASE/httpd.conf"
chmod 600 "$BASE/httpd.conf"

# Only stop the dedicated Web UI server; never use killall httpd.
for pid in $(ps | grep '[h]ttpd' | grep '192[.]168[.]169[.]1:8088' | awk '{print $1}'); do
    kill "$pid" 2>/dev/null
done
sleep 1
sh "$BASE/udhcpd-notify.sh"
```

Bỏ Basic Auth sẽ có hiệu lực cả sau reboot vì `httpd.conf` nằm trên `/data`. Nếu **chưa cài Web UI** thì chỉ xóa auth không tạo được giao diện; hãy theo mục 3.

## 7. Tùy chỉnh và rollback

- File preset lưu: `/data/x10pro-display/display.conf` (ví dụ `R=100`, `G=100`, `B=50`, `LIGHT=100`).
- Callback cũ được backup: `/data/x10pro-display/udhcpd-notify.sh.pre-webui`.
- Cấu hình Basic Auth cũ (nếu có) được backup: `/data/x10pro-display/httpd.conf.auth.bak`.
- Log HTTP/CGI tạm nằm trong `/tmp` và không bền sau reboot.

Để **gỡ Web UI** và trở lại callback Blue-only ban đầu:

```sh
BASE=/data/x10pro-display
if [ -f "$BASE/udhcpd-notify.sh.pre-webui" ]; then
    cp -p "$BASE/udhcpd-notify.sh.pre-webui" "$BASE/udhcpd-notify.sh"
    sync
    reboot
else
    echo "No pre-WebUI callback backup; do not overwrite blindly."
fi
```

Để **bật lại Basic Auth** nếu đã sao lưu, khôi phục `httpd.conf.auth.bak`, rồi restart riêng server 8088. Nếu không còn backup, cần tự cấu hình lại mật khẩu.

## 8. Bảo mật và giới hạn

**Cảnh báo:** Không có Basic Auth đồng nghĩa **mọi thiết bị kết nối được hotspot** đều có thể gọi CGI và chỉnh LCD. CGI đang chạy với quyền cao để ghi driver; mặc dù đầu vào được kiểm tra, không nên để cổng 8088 truy cập từ mạng ngoài, không dùng mật khẩu hotspot yếu, và không bật bridge/forward port từ các mạng không tin cậy.

- Telnet và HTTP không mã hóa.
- Preset chỉ đổi ma trận CSC màn LCD, không sửa video trong thẻ.
- Gọi DHCP callback khoảng mỗi 5 giây khi dịch vụ hoạt động; không cam kết áp ngay 5 giây kể từ bật nguồn.
- Không khắc phục hiện tượng Wi-Fi hotspot tự tắt hoặc lần boot không phát Wi-Fi.
- Web UI đã được xây dựng dựa trên CGI đã test; **chưa xác nhận end-to-end sau khi cài trên máy thực**.
