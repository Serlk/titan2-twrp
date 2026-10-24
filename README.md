# TWRP for the Unihertz Titan 2

TWRP 3.7.1 (Android 14 base, `twrp-14.1`) for the Unihertz Titan 2 (MediaTek MT6878 /
Dimensity 7300, GKI 6.1, A/B, stock firmware V01.00.14).

Installation: [docs/INSTALL.md](docs/INSTALL.md) · По-русски: [docs/INSTALL.ru.md](docs/INSTALL.ru.md)

## What works

- Main display, touchscreen, hardware keyboard, volume/power keys
- **`/data` decryption**: FBE v2 with metadata encryption; the lock screen PIN/pattern/password is
  checked by the phone's own TrustKernel TEE (KeyMint 3, Gatekeeper)
- adb (shell, push/pull, sideload), fastbootd
- Flashing images and zips, wipe/format, backup/restore of partitions (boot, init_boot,
  vendor_boot, dtbo, vbmeta*, super, NV and protect partitions as raw images)
- Russian and other languages (no CJK fonts, see below)

Not working / not done:

- **Switching the active slot** in TWRP: TWRP talks to the HIDL boot HAL, the phone has the AIDL
  MediaTek one. It fails without changing anything. Do not switch slots.
- MTP is off (it took the whole USB gadget down); copy files with `adb push` / `adb pull`.
- The theme is the 1080×1920 one scaled to the square 1440×1440 screen.

## How it works

The Titan 2 has no recovery partition: the recovery is the RECOVERY ramdisk fragment of
`vendor_boot` (boot image header v4). LK, the bootloader, loads the PLATFORM fragment on every
boot and adds the RECOVERY fragment on top of it only when it boots into recovery.

- **This project replaces only the RECOVERY fragment.** The PLATFORM fragment (first stage init,
  the stock kernel modules), the dtb and the header stay byte for byte those of your phone, so a
  normal Android boot does not read anything from this project.
- **Nothing proprietary is in the TWRP image.** Kernel modules (the main touchscreen
  `synaptics_tp`, the keyboard `aw9523_key`, `kb_touchpad`, the keyboard touchpad
  `synaptics_1403_touch`) are loaded from the phone's own `vendor_boot` and `vendor_dlkm`. The TEE
  services for decryption (`teed`, KeyMint, Gatekeeper) run from the phone's own `vendor`
  partition, with the command lines of its own init scripts (`system/bin/vendor-service.sh`).
- The release publishes the TWRP fragment and `tools/titan2-twrp-vendor-boot.py`, which puts it
  into your own `vendor_boot` image. The resulting image is yours; it contains the stock
  PLATFORM fragment and must not be redistributed.

### The bootloader's ramdisk limit

LK copies all vendor ramdisk fragments, the init_boot ramdisk and the bootconfig into a 64 MiB
region **on every boot, Android included**. If they do not fit, the phone does not boot at all.
TWRP leaves about 8 MiB free with a root-patched init_boot. That is why the CJK fonts are left
out; both `scripts/build.sh` and the release tool check the limit.

### /data decryption

`system/bin/prepdecrypt.sh` runs right before TWRP decrypts (`patches/bootable_recovery/0001`):
it mounts the real `vendor` partition and `protect1` (`/mnt/vendor/protect_f`, the TEE storage),
and starts `teed`, KeyMint and Gatekeeper. teed is started as Android starts it before `/data` is
decrypted (`vendor.trustkernel.fs.state` is never set to `ready`), so it does not use its storage
on `/data`.

Gatekeeper updates its records on `protect1` when it checks the PIN. They must keep the vendor
SELinux label (`tkcore_protect_data_file`): with any other label Android's teed cannot open them,
treats the object as corrupt and deletes it, and Gatekeeper then rejects the PIN in Android. The
recovery policy therefore has the vendor types of that storage (`sepolicy/tee_storage.te`; new
files inherit their directory's label), and `system/bin/tee-labels.sh` checks the labels against
the phone's `vendor_file_contexts` before every reboot or power off from TWRP.

TWRP `twrp-14.1` does not build or work with encryption on this device as it is; the patches:

| Patch | What |
|---|---|
| `bootable_recovery/0001` | run `/system/bin/prepdecrypt.sh` before decrypting |
| `bootable_recovery/0002` | Android 14 keystore2 AIDL library names; libvold dependencies |
| `bootable_recovery/0003` | libtar: the fscrypt policy type and helpers missing from the branch |
| `bootable_recovery/0004` | stand-ins for the FDE functions removed from the Android 14 vold |
| `bootable_recovery/0005` | pass the new `zoned_device` argument to vold (the metadata key was looked up under `default/`) |
| `system_vold/0001` | check the PIN with the AIDL Gatekeeper when there is no HIDL one; hand the auth token to keystore2 |

Device tree fixes for the Android 14 recovery: a framework VINTF base manifest (and framework
copies of the two stock device fragments that otherwise make servicemanager reject the whole
framework manifest), a declaration of the TEE HALs, the bootstrap linker path for
servicemanager, `task_profiles.json` for logd, SELinux permissive in recovery only
(`sepolicy/twrp_permissive.te`: the kernel command line is shared with Android).

## Building

Linux, Docker, about 90 GB for the sources and the build.

```
scripts/sync.sh                 # TWRP sources (twrp-14.1 minimal manifest) into src/, in Docker
scripts/extract-stock.sh        # your stock vendor_boot, boot, init_boot into stock/ (not committed)
scripts/build.sh                # build; out/twrp-titan2-recovery.lz4 and out/vendor_boot-twrp.img
scripts/flash-test.sh check|flash|restore
```

`extract-stock.sh` takes the images from `VENDOR_BOOT=`, `BOOT=`, `INIT_BOOT=` (defaults: a
backup of the titan2-linux project next to this one); `out/vendor_boot-twrp.img` is packed from
your vendor_boot, no kernel is part of the output. The Docker image is the AOSP build image of
[titan2-android](https://github.com/Serlk/titan2-android): `docker build -t titan2-aosp docker/aosp`.

## Repository rules

No stock or proprietary file is ever committed: `stock/`, `src/`, `out/`, `work/`, `*.img`, `*.ko`
are ignored, and the device tree is written from what the phone exposes (partition names,
module names, SELinux type names), not copied from the vendor's files.

## License

GPL-2.0-or-later for this repository (see [LICENSE](LICENSE)); TWRP and AOSP are under their own
licenses.
