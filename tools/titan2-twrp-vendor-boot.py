#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Put TWRP into YOUR OWN Titan 2 vendor_boot image.

On the Unihertz Titan 2 the recovery is the RECOVERY ramdisk fragment of vendor_boot (boot image
header v4). This tool takes your vendor_boot (dumped from your phone, or from the official
firmware package of exactly the version on your phone), replaces that fragment with the TWRP one
from the release, and writes a new image. Everything else is kept byte for byte: the header, the
PLATFORM fragment (kernel modules and first stage, used by every Android boot), the dtb and the
bootconfig. The proprietary parts therefore never leave your phone and are not distributed.

    python3 titan2-twrp-vendor-boot.py vendor_boot_a.img twrp-recovery.lz4 vendor_boot-twrp.img \
        [--init-boot init_boot_a.img]

The bootloader (LK) copies all vendor ramdisk fragments, the init_boot ramdisk and the
bootconfig into a 64 MiB region on every boot; if they do not fit, the phone does not boot at
all. The tool checks that (give --init-boot for the exact size of yours; without it a generous
estimate is used) and refuses to write an image that would not fit.

Python 3.6+, no other dependencies; works on Linux, macOS and Windows.
"""

import argparse
import hashlib
import struct
import sys

VENDOR_BOOT_MAGIC = b"VNDRBOOT"
BOOT_MAGIC = b"ANDROID!"
# vendor_boot v4 header, up to and including bootconfig_size
HDR_FMT = "<8sIIIII2048sI16sIIQIIII"
HDR_SIZE = struct.calcsize(HDR_FMT)  # 2128
ENTRY_FMT = "<III32s64s"  # size, offset, type, name, board_id[16]
ENTRY_SIZE = struct.calcsize(ENTRY_FMT)  # 108
TYPE_PLATFORM, TYPE_RECOVERY = 1, 2
LK_RAMDISK_LIMIT = 64 * 1024 * 1024  # LK mb_ramdisk, the sum + 0x400 must fit
INIT_BOOT_ESTIMATE = 6 * 1024 * 1024  # a root-patched init_boot ramdisk is ~3-5 MiB


def align(n, page):
    return (n + page - 1) // page * page


def fail(msg):
    sys.exit("error: " + msg)


def parse(img):
    if len(img) < HDR_SIZE or img[:8] != VENDOR_BOOT_MAGIC:
        fail("not a vendor_boot image (no VNDRBOOT magic)")
    f = struct.unpack_from(HDR_FMT, img)
    h = dict(zip(("magic", "version", "page", "kernel_addr", "ramdisk_addr", "ramdisk_size",
                  "cmdline", "tags_addr", "name", "header_size", "dtb_size", "dtb_addr",
                  "table_size", "entry_num", "entry_size", "bootconfig_size"), f))
    if h["version"] != 4:
        fail("vendor_boot header version %d, expected 4" % h["version"])
    if h["entry_size"] != ENTRY_SIZE:
        fail("unexpected ramdisk table entry size %d" % h["entry_size"])
    page = h["page"]
    off_ramdisk = align(h["header_size"], page)
    off_dtb = off_ramdisk + align(h["ramdisk_size"], page)
    off_table = off_dtb + align(h["dtb_size"], page)
    off_bootconfig = off_table + align(h["table_size"], page)
    end = off_bootconfig + align(h["bootconfig_size"], page)
    if end > len(img):
        fail("vendor_boot image is truncated")
    entries = []
    for i in range(h["entry_num"]):
        size, offset, rtype, name, board = struct.unpack_from(ENTRY_FMT, img, off_table + i * ENTRY_SIZE)
        if offset + size > h["ramdisk_size"]:
            fail("ramdisk table entry %d points outside the vendor ramdisk" % i)
        data = img[off_ramdisk + offset:off_ramdisk + offset + size]
        entries.append({"type": rtype, "name": name, "board": board, "data": data})
    return h, entries, img[off_dtb:off_dtb + h["dtb_size"]], \
        img[off_bootconfig:off_bootconfig + h["bootconfig_size"]]


def build(h, entries, dtb, bootconfig):
    page = h["page"]
    ramdisk = b"".join(e["data"] for e in entries)
    table, offset = b"", 0
    for e in entries:
        table += struct.pack(ENTRY_FMT, len(e["data"]), offset, e["type"], e["name"], e["board"])
        offset += len(e["data"])
    hdr = struct.pack(HDR_FMT, VENDOR_BOOT_MAGIC, 4, page, h["kernel_addr"], h["ramdisk_addr"],
                      len(ramdisk), h["cmdline"], h["tags_addr"], h["name"], HDR_SIZE, len(dtb),
                      h["dtb_addr"], len(table), len(entries), ENTRY_SIZE, len(bootconfig))
    out = b""
    for part in (hdr, ramdisk, dtb, table, bootconfig):
        out += part + b"\0" * (align(len(part), page) - len(part))
    return out


def init_boot_ramdisk_size(path):
    with open(path, "rb") as f:
        hdr = f.read(16)
    if hdr[:8] != BOOT_MAGIC:
        fail("%s is not a boot image (no ANDROID! magic)" % path)
    return struct.unpack_from("<I", hdr, 12)[0]  # v3/v4: kernel_size, ramdisk_size


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("vendor_boot", help="your stock vendor_boot image")
    ap.add_argument("fragment", help="TWRP recovery fragment from the release (.lz4)")
    ap.add_argument("output", help="vendor_boot image to write")
    ap.add_argument("--init-boot", help="the init_boot image on your phone, for the size check")
    a = ap.parse_args()

    with open(a.vendor_boot, "rb") as f:
        img = f.read()
    with open(a.fragment, "rb") as f:
        twrp = f.read()
    if twrp[:4] not in (b"\x02\x21\x4c\x18", b"\x04\x22\x4d\x18"):
        fail("%s is not an lz4 ramdisk" % a.fragment)

    h, entries, dtb, bootconfig = parse(img)
    platform = [e for e in entries if e["type"] == TYPE_PLATFORM]
    recovery = [e for e in entries if e["type"] == TYPE_RECOVERY]
    if len(platform) != 1 or len(recovery) != 1:
        fail("expected one PLATFORM and one RECOVERY fragment, found %d and %d"
             % (len(platform), len(recovery)))
    print("stock PLATFORM fragment: %d bytes, kept as is" % len(platform[0]["data"]))
    print("RECOVERY fragment: %d bytes -> TWRP %d bytes" % (len(recovery[0]["data"]), len(twrp)))
    recovery[0]["data"] = twrp

    ib = init_boot_ramdisk_size(a.init_boot) if a.init_boot else INIT_BOOT_ESTIMATE
    total = sum(len(e["data"]) for e in entries) + ib + len(bootconfig) + 0x400
    print("LK ramdisk region: %d of %d bytes (init_boot ramdisk %d%s), %d KiB free"
          % (total, LK_RAMDISK_LIMIT, ib, "" if a.init_boot else " estimated",
             (LK_RAMDISK_LIMIT - total) // 1024))
    if total > LK_RAMDISK_LIMIT:
        fail("too big for the bootloader: the phone would not boot at all. Nothing written.")

    out = build(h, entries, dtb, bootconfig)
    # check: the new image parses, everything but the RECOVERY fragment is unchanged
    h2, e2, dtb2, bc2 = parse(out)
    same = (dtb2 == dtb and bc2 == bootconfig and h2["cmdline"] == h["cmdline"]
            and [e["data"] for e in e2 if e["type"] == TYPE_PLATFORM] == [platform[0]["data"]]
            and [e["data"] for e in e2 if e["type"] == TYPE_RECOVERY] == [twrp])
    if not same:
        fail("internal check failed, nothing written")
    with open(a.output, "wb") as f:
        f.write(out)
    print("written %s (%d bytes, sha256 %s)" % (a.output, len(out), hashlib.sha256(out).hexdigest()))


if __name__ == "__main__":
    main()
