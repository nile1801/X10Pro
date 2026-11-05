# X10Pro RGB Web UI — no firmware flash

Web UI chỉnh R/G/B và backlight LCD trực tiếp trên X10Pro LomboTech N7, chạy bằng **BusyBox httpd + CGI shell** đã kiểm chứng ở chế độ thử nghiệm trên camera.

## Tính năng
- Giao diện trình duyệt: `http://192.168.169.1:8088/`.
- Slider RGB và backlight 0–100%, xem trước trực tiếp.
- **Save** lưu preset vào `/data/x10pro-display/display.conf`; không ghi flash liên tục khi kéo thanh trượt.
- Preview hết hạn sau **120 giây**, callback DHCP sẽ khôi phục preset đã lưu.
- Callback DHCP sẵn có (5 giây) tự khởi động HTTP daemon sau reboot và tự áp preset đã lưu.
- Mật khẩu Web UI ngẫu nhiên được tạo **trên thiết bị**, không lưu trong repo.

## Điều kiện

Chỉ dùng với các X10Pro có đúng đường dẫn:
- `/sys/bus/platform/devices/1602000.tcon/csc`
- `/sys/class/backlight/pwm3_backlight/{brightness,max_brightness}`
- `/data/wifi/udhcpd.conf` đã có `notify_file /data/x10pro-display/udhcpd-notify.sh`.

Thiết bị thử nghiệm có `/data` chỉ 64 KiB. Installer kiểm tra dung lượng trước khi ghi. Các hệ số r0/g1 đọc được nhưng **chưa được thử điều chỉnh thực tế** trên máy của anh; trước khi kéo nhiều, hãy kiểm tra bước nhỏ.

## Cài qua Telnet

1. Kết nối mạng Wi-Fi của camera và Telnet vào `192.168.169.1` bằng quyền root.
2. Mở [install-standalone.sh](./install-standalone.sh), copy toàn bộ script và chuyển vào máy qua phiên Telnet (nên paste vào `/tmp/install-webui.sh` bằng here-document, rồi chạy `sh /tmp/install-webui.sh`).
3. Installer kiểm tra tương thích, sao lưu callback đang chạy thành `udhcpd-notify.sh.pre-webui`, tạo các file trong `/data/x10pro-display` và bật daemon.
4. **Ghi lại mật khẩu được in trên Telnet**. Mở `http://192.168.169.1:8088/`, đăng nhập tài khoản `admin`.
5. Từ laptop, **xác minh HTTP 401 khi chưa gửi credentials**:

```powershell
curl.exe -i --max-time 8 http://192.168.169.1:8088/
```

Nếu không yêu cầu đăng nhập, **đừng dùng Web UI để chỉnh màu**: firmware có thể không bật HTTP Basic Auth như dự kiến.

Camera thường không có Internet, vì thế `wget` trực tiếp từ GitHub trên camera có thể không hoạt động; cách paste qua Telnet không cần Internet.

## Kiểm tra trên máy

```sh
ps | grep '[h]ttpd'
cat /data/x10pro-display/display.conf
cat /sys/bus/platform/devices/1602000.tcon/csc
cat /sys/class/backlight/pwm3_backlight/brightness
cat /tmp/x10pro-webui-httpd.log 2>/dev/null
```

## Rollback

```sh
cp -p /data/x10pro-display/udhcpd-notify.sh.pre-webui \
    /data/x10pro-display/udhcpd-notify.sh
sync
reboot
```

Giữ nguyên backup DHCP gốc, không xóa khi chưa xác minh Wi-Fi hoạt động trở lại.

## Giới hạn an toàn

- HTTP Basic Auth không mã hóa, chỉ sử dụng qua hotspot Wi-Fi tin cậy và không mở port 8088 ra Internet.
- Chưa thử điều chỉnh R/G trên X10Pro thật; việc thử cần cẩn trọng, tránh kéo ngay về 0.
- Hotspot phải chạy thì DHCP callback/Web UI mới hoạt động. **Bản này không khắc phục Wi-Fi tự tắt.**
- Thay đổi chỉ ảnh hưởng hiển thị LCD, không ảnh hưởng video được ghi.
