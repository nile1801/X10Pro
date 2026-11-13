# Camera Color Lab — X10Pro v1.3.1

**Đã chạy trên máy thực (13/11/2026):** Web UI có năm slider và preset, Test 30 giây + tự restore, Apply tối đa 15 phút, lưu Slot 1–3, lưu Auto Apply, liên kết qua Display Control. Hotfix v1.3.1 khắc phục dropdown/slider không khớp cấu hình đã lưu khi F5. `/usr/bin/sar` không bị thay thế.

[Hướng dẫn cài và kiểm thử đầy đủ cả hai Web UI](../docs/INSTALL_TWO_WEBUIS.md).

[Manifest kiểm chứng mã nguồn, checksum và tình trạng phát hành archive](SOURCE_RELEASE_MANIFEST.md).

Để đưa archive source/runtime đã kiểm SHA lên nhánh `main`, có [script PowerShell đồng bộ source](sync-source-from-archive.ps1). Script cần archive `X10Pro_ColorLab_runtime_sources_v1.2-v1.3.1.tar.gz` từ gói đã tạo, Git và quyền push; nó clone repo mới, chỉ thêm `camera-color/src`, commit và push không force. **Lưu ý:** source/runtime được khôi phục từ các gói v1.2/v1.3/v1.3.1 nhưng archive chưa được đưa lên GitHub; tài liệu trong repo hiện chưa đủ để cài Color Lab mới hoàn toàn từ GitHub.

## Phiên bản và phụ thuộc

- **Display Control**: source ở `webui/`, địa chỉ `http://192.168.169.1:8088/`.
- **Color Lab v1.2**: cần có sẵn helper ARM ở `/mnt/card/x10pro-color/tp9963_color5_step.arm` và controller.
- **v1.3**: gói nâng cấp `X10Pro_ColorLab_v1.3_30s_AutoBoot.zip` (gồm `deploy_telnet.txt`, CGI, controller, boot hook, ARM helper); **không phải fresh installer**.
- **v1.3.1**: `X10Pro_ColorLab_v1.3.1_UI_State_Fix.zip` là *UI-only hotfix*. Nó không sửa controller hoặc thanh ghi. Đường dẫn `/camera.html?v=131`.

**Để tái tạo từ đầu:** cần đầy đủ bộ cài v1.2, v1.3 và v1.3.1; chỉ có HTML hoặc các lệnh trong README là không đủ. Gói ZIP là các artifact đã thử trên gương, chưa được xuất bản làm GitHub Release trong lần commit tài liệu này.

## Các lệnh chuẩn

```sh
# Trước khi thử
sh /mnt/card/x10pro-color/controller.sh preflight
sh /mnt/card/x10pro-color/controller.sh status

# Sau Test 30 giây, yêu cầu khôi phục hoàn tất
sh /mnt/card/x10pro-color/controller.sh report
sh /mnt/card/x10pro-color/controller.sh status

# Sau reboot — kiểm tra cấu hình và Auto Apply
cat /data/x10pro-display/camera-startup.conf
cat /tmp/x10pro-color5-boot.log
sh /mnt/card/x10pro-color/controller.sh status
```

Máy kiểm chứng trả `BOOT_PROFILE_APPLIED`, `ACTIVE_BOOT_UNTIL_RESTORE_OR_REBOOT`, readback `SAT=0x50 CON=0x46 BRI=0x00 HUE=0x00 SHARP=0x02` với profile `80/70/0/0/2`. Đây là readback lúc Apply, không phải giám sát thời gian thực về sau.

## Hotfix trên /data 64 KiB

Khi chỉ còn ~16 KiB trên `/data`, installer hotfix chuẩn có thể từ chối vì cần ít nhất 19 KiB để tạo bản copy tạm. **Không xóa `/data/sar`, `/data/wifi`, `display.conf`, `camera-startup.conf`.**

Với đúng `camera.html` v1.3 (SHA `d987ea42fab2088f92879e172af27ab5e6a557afff913f48ac43633ec381e39c`) và patch v1.3.1 (SHA `b089e82dc85b8cb8a8696a5a558e9b17f97c1ca406c8f9f8a3a4a12c1b99f8c3`), có thể sao lưu file cũ sang SD, xác minh bản sao rồi thay nội dung file tại chỗ. Phải có đủ source patch tại `/tmp/x10pro_color131_patch/camera.html`. Xem hướng dẫn cụ thể trong gói v1.3.1 hoặc script đã thử; phương án direct-write *không nguyên tử* nên không cúp nguồn, luôn lưu bản sao tại `/mnt/card/x10pro-color/backups/camera.html.pre-v131`.

## Tự khởi động và rollback

Cơ chế boot là `/data/x10pro-display/udhcpd-notify.sh` gọi `/mnt/card/x10pro-color/boot_apply.sh` (fallback). `/etc/init.d` trên máy thử là read-only, nên installer báo `BOOT_HOOK=wifi_dhcp_only`. **Nếu Wi-Fi/DHCP không chạy, profile có thể không được áp.**

```sh
# Hủy trạng thái đang áp, nếu có
sh /mnt/card/x10pro-color/controller.sh restore
# Vô hiệu profile boot cho lần bật nguồn tiếp
sh /mnt/card/x10pro-color/controller.sh boot_disable
# Chỉ rollback toàn bộ v1.3 khi controller INACTIVE và có backup đầy đủ
sh /mnt/card/x10pro-color/rollback_v13.sh
```

Bản Color Lab không cung cấp HDR/Gamma hay thuật toán 70mai thật: tên profile hãng chỉ là tham khảo phong cách màu. Vì controller vẫn dùng SIGSTOP/SIGCONT quanh ghi I²C nên không thử khi đang lái xe hoặc cần ghi hình quan trọng.
