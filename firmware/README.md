# X10Pro firmware / device dump (research only)

**Important:** This folder documents a **partial backup of a specific XETABON X10Pro unit**, not a complete firmware image and **not a flashable OTA package**.

| Item | Value |
| --- | --- |
| Camera | XETABON X10Pro (FHCam), LomboTech N7 |
| Device firmware version | `20251103.180135` |
| OS | Linux Virgo `4.19.73` / `sar-Linux-v1.0alpha3` |
| Captured | 2026-11-05 |
| Original archive name | `x10pro_rgb_20261105_204720.tar.gz` |
| Archive size | **14,023,684 bytes** |
| SHA-256 | `3e6e293df65a49b46dc9c6f1fade05f76ec9d74793ca148f853cb717a363d4fa` |

The original archive was obtained directly from the device and **was not modified during inspection**. The archived files include:
- `images/mtd0.bin` — **786,432 bytes**, LEAVER / U-Boot bootloader partition.
- `images/mtd1.bin` — **11,599,872 bytes**, SquashFS root filesystem (`root_sq`).
- `images/sar_running.elf` — **5,124,360 bytes**, running camera app copy.
- `images/running_device_tree.dtb` — flattened DTB.
- `images/proc_device_tree.tar` — runtime device tree.
- `info/*` — system metadata and diagnostic logs.

The device also reports partitions `mtd2` (`misc`) and `mtd3` (`userdata`), but **these were deliberately not collected**. Some flash regions are not represented in the MTD partition set. This is therefore **not a full SPI-NOR (16 MiB) backup**.


## Critical safety warnings

- **DO NOT FLASH** `mtd0.bin`, `mtd1.bin`, or the `.tar.gz` file directly to the camera.
- The archive is **not** a verified `package.efw` (vendor OTA) and no recovery path has been validated.
- Root filesystem and executable images may contain vendor proprietary code or security-sensitive defaults. **Review authorization, redistribution rights, and content before publishing in a public repository.** Git history is persistent; removing a file later does not reliably undo disclosure.
- The *display Web UI* and *DHCP auto-apply script* under [webui](../webui) operate without firmware flashing.

Per-file hashes are recorded in [SHA256SUMS.txt](./SHA256SUMS.txt).
