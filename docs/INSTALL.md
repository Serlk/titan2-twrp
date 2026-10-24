Русский: [INSTALL.ru.md](INSTALL.ru.md)

# Installing TWRP on the Unihertz Titan 2

TWRP 3.7.1 for the Titan 2: display, touchscreen, hardware keyboard, adb, sideload, fastbootd,
flashing and backups, and **`/data` decryption with your lock screen PIN**.

The release does not contain a ready `vendor_boot` image: that would include Unihertz/MediaTek
files. It contains the TWRP part only, and a script that puts it into **your own** `vendor_boot`.

> **Warning.** You need an unlocked bootloader. Read everything before you start. Everything you
> do is at your own risk.

---

## 1. What you need

| What | Why |
|---|---|
| Titan 2 (MT6878), firmware **V01.00.14** (stock Android 16, or crDroid / a GSI on top of its vendor) | TWRP is built and tested against it |
| Unlocked bootloader | the phone does not accept a modified vendor_boot otherwise |
| PC with Linux, Windows or macOS: recent `platform-tools` (adb/fastboot) and **Python 3** | building your image, flashing |
| Root on the phone (Magisk/KernelSU) — recommended | dumping your own vendor_boot and the backups of step 3 |
| Release files | `twrp-titan2-recovery-<date>.lz4`, `titan2-twrp-vendor-boot.py`, `SHA256SUMS` |

Check the downloads: `sha256sum -c SHA256SUMS`.

---

## 2. Never do this

- **Do not flash or erase** `preloader`, `lk`, `seccfg`, `tee`, `nvram`, `nvdata`, `nvcfg`,
  `protect1`, `protect2`, `proinfo`, `md*`. IMEI, calibrations and the TEE keys live there and are
  lost for good.
- **Do not switch the active slot in TWRP** (Reboot → slot A/B). It does not work on this phone
  and slot B holds old bootloader images.
- **Do not tap Format Data / Wipe** if decryption fails: it erases everything. Ask for help with
  the log instead (step 7).
- **Do not use `adb reboot recovery` the first time.** Android then writes a "boot recovery"
  command for the bootloader, and LK obeys it *before* it looks at the buttons: as long as the
  command is there, the phone boots into recovery every time and the button menu (and fastboot)
  cannot be reached. TWRP clears it when you reboot from its menu. For the first try, enter
  recovery with the buttons (step 5).

---

## 3. Backup (do not skip)

With root, in Android (`adb shell`, then `su`), or with adb in TWRP **before you enter the PIN**:

```
adb exec-out su -c 'dd if=/dev/block/by-name/vendor_boot_a' > vendor_boot_a.img
adb exec-out su -c 'dd if=/dev/block/by-name/init_boot_a'   > init_boot_a.img
adb exec-out su -c 'dd if=/dev/block/by-name/protect1'      > protect1.img
adb exec-out su -c 'dd if=/dev/block/by-name/protect2'      > protect2.img
adb exec-out su -c 'dd if=/dev/block/by-name/metadata'      > metadata.img
adb exec-out su -c 'dd if=/dev/block/by-name/nvram'       > nvram.img
adb exec-out su -c 'dd if=/dev/block/by-name/nvdata'      > nvdata.img
adb exec-out su -c 'dd if=/dev/block/by-name/nvcfg'       > nvcfg.img
adb exec-out su -c 'dd if=/dev/block/by-name/proinfo'     > proinfo.img
```

(`exec-out` keeps the data binary. In TWRP adb is already root: leave out `su -c`, i.e.
`adb exec-out dd if=/dev/block/by-name/vendor_boot_a > vendor_boot_a.img`.)

What each one is for:

| Image | Why |
|---|---|
| `vendor_boot_a` | your stock vendor_boot: input of step 4 and the way back |
| `init_boot_a` | the size check of step 4 |
| `protect1`, `protect2` | TEE storage (Gatekeeper and KeyMint records). TWRP's decryption runs the TEE, which updates them; if Android ever stops accepting your PIN after TWRP, these get it back |
| `metadata` | the metadata encryption key of `/data` |
| `nvram`, `nvdata`, `nvcfg`, `proinfo` | IMEI and calibrations — keep them anyway |

Keep the images off the phone. Check the active slot: `adb shell getprop ro.boot.slot_suffix`
(normally `_a`; with `_b` use `_b` everywhere below).

Without root: take `vendor_boot.img` and `init_boot.img` from the official firmware package of
**exactly the version installed** on your phone (Settings → About phone). A vendor_boot of
another version has kernel modules that do not match your kernel.

---

## 4. Build your image

```
python3 titan2-twrp-vendor-boot.py vendor_boot_a.img twrp-titan2-recovery-<date>.lz4 vendor_boot-twrp.img --init-boot init_boot_a.img
```

It keeps everything of your vendor_boot except the recovery part, and checks the bootloader's
64 MiB ramdisk limit (the phone does not boot at all if it is exceeded). It writes nothing if
something is wrong. Expected output ends with `... KiB free` and `written vendor_boot-twrp.img`.

---

## 5. Flash and enter TWRP

```
adb reboot bootloader
fastboot getvar current-slot          # a
fastboot flash vendor_boot_a vendor_boot-twrp.img
fastboot reboot
```

Android boots as before (TWRP is only read when booting into recovery).

To enter TWRP: power off, hold **Power + Func1** (the upper extra key on the side). The bootloader
menu appears: move with the extra keys, choose **Recovery** and confirm with **Volume Up**.

---

## 6. First start

1. TWRP decrypts the `/data` metadata by itself, then asks for your lock screen **PIN** (or
   pattern/password). Enter it: the internal storage becomes available.
2. Leave TWRP with **Reboot → System**. Before every reboot or power off, TWRP fixes the
   SELinux labels of the TEE records it touched, so Android accepts your PIN as usual.
3. Copy files with `adb pull /sdcard/...` and `adb push`; MTP is off.

---

## 7. Problems

| Problem | What to do |
|---|---|
| The phone boots into TWRP every time | reboot from TWRP's menu (Reboot → System). If TWRP is not usable but adb works: `adb shell dd if=/dev/zero of=/dev/block/by-name/misc bs=2048 count=1` (clears only the boot command), then `adb reboot` |
| "Wrong PIN" in Android after TWRP | do not try again and again (Gatekeeper slows down). Connect adb and look at `logcat \| grep -i gatekeeper`; the TEE records are on `protect1` (`/mnt/vendor/protect_f/tee`): `restorecon -RF /mnt/vendor/protect_f/tee`, or restore the record from your `protect1.img` backup |
| TWRP does not decrypt | `adb pull /tmp/recovery.log` and `adb logcat`; do not format |
| Back to stock recovery | `fastboot flash vendor_boot_a vendor_boot_a.img` (your backup) |
| Fastboot not reachable | power off, Power + Func1, choose Fastboot (only works while no boot command is set, see the first row) |

Sources and how it works: [README.md](../README.md).
