# Camera Color Lab — source/runtime manifest (2026-11-13)

This is a **verification manifest**, not a firmware image or a self-contained installer.

The repository currently documents X10Pro Display Control and Camera Color Lab; the tested Camera Color Lab runtime was generated as versioned archives. Preserve exact checksums when transferring the tested files.

## Tested versions

| Version | Purpose | Hardware status |
|---|---|---|
| v1.2 | 5-register TP9963 bank 0 controller, temporary preview/restore | 5-register I2C write/readback/restore confirmed |
| v1.3 | Web UI, 30-second preview, 15-minute apply, auto-apply from Wi-Fi/DHCP callback | Preview and boot auto-apply confirmed on one X10Pro |
| v1.3.1 | HTML-only fix for F5 dropdown/slider state | User confirmed working after upgrade |

## Verified SHA-256

```text
cb8c071eb7b9c976a32bf7a5628e5ddc18444a868127e2aa52ba3b87eeee8f56  tp9963_color5_step.arm
327f8b5f1108824874cdb529328de852028a7f47a5eb76abe82cbbae46a484ef  v1.3/device/controller.sh
ab40eb016211b6661191d65eb4887658bc6d4be570a1522cdc4623b19a5c26ee  v1.3/www/cgi-bin/camera.cgi
d987ea42fab2088f92879e172af27ab5e6a557afff913f48ac43633ec381e39c  v1.3/www/camera.html
b089e82dc85b8cb8a8696a5a558e9b17f97c1ca406c8f9f8a3a4a12c1b99f8c3  v1.3.1/patch/camera.html
```

Source/runtime reconstruction archive, including v1.2, v1.3, and v1.3.1 device source and ARM binaries:
`X10Pro_ColorLab_runtime_sources_v1.2-v1.3.1.tar.gz`

```text
1b4040d76f48dc4489f5875df72dd39a6ef32490aab9942c234cc456b4db81c4  X10Pro_ColorLab_runtime_sources_v1.2-v1.3.1.tar.gz
```

**Archive publication status:** not yet attached to GitHub Release or committed into this repository. Do not claim that the repository alone can reinstall Camera Color Lab on a blank device until the complete tested runtime is published and installation is validated from that archive.

## Deploy order

1. Verify the device model, firmware, SHA of `/usr/bin/sar`, and free space.
2. Install Display Control first using [webui instructions](../webui/README.md).
3. Install Color Lab v1.2 (initial controller) and then upgrade to v1.3; install the v1.3.1 UI-only patch last.
4. If v1.3 is already installed and working, **do not reinstall Display Control**. It may overwrite the DHCP callback that applies the camera profile after reboot.
5. For limited `/data` free space, refer to the safe low-space HTML replacement process in [Camera Color Lab guide](README.md).

Only work while parked and on stable power. The controller pauses `sar` briefly while changing the TP9963 bank. The firmware root filesystem was read-only on the tested camera, so auto-apply is Wi-Fi/DHCP-dependent. Never flash the collected firmware dumps as an update.
