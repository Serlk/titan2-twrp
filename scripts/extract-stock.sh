#!/usr/bin/env bash
# Take what the recovery needs from YOUR OWN stock firmware into stock/ (not committed):
#  - vendor_boot.img (its PLATFORM fragment goes into our image unchanged);
#  - the stock RECOVERY fragment, unpacked (reference: init.recovery.*.rc, fstab, sepolicy);
#  - the GKI kernel from boot.img (the build wants one; our image does not carry it);
#   VENDOR_BOOT=<stock vendor_boot.img> BOOT=<stock boot.img> \
#     scripts/extract-stock.sh
# Defaults: the stock backup of the titan2-linux project next to this one.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T2=$(cd "$ROOT/../titan2-linux" 2>/dev/null && pwd || true)
VENDOR_BOOT=${VENDOR_BOOT:-$T2/backup/20261017-V01.00.14/vendor_boot_a.img}
BOOT=${BOOT:-$T2/backup/20261017-V01.00.14/boot_a.img}
INIT_BOOT=${INIT_BOOT:-$T2/backup/20261017-V01.00.14/init_boot_a.img}
UNPACK=${UNPACK:-$ROOT/src/system/tools/mkbootimg/unpack_bootimg.py}

for f in "$VENDOR_BOOT" "$BOOT"; do [ -f "$f" ] || { echo "no stock image: $f" >&2; exit 1; }; done
S=$ROOT/stock
rm -rf "$S"; mkdir -p "$S/vendor_boot" "$S/boot"
cp "$VENDOR_BOOT" "$S/vendor_boot.img"
cp "$BOOT" "$S/boot.img"
# unpack_bootimg comes with the TWRP sources (system/tools/mkbootimg); run it in the build image
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/w" -w /w titan2-aosp \
  python3 "${UNPACK#$ROOT/}" --boot_img stock/vendor_boot.img --out stock/vendor_boot \
  --format mkbootimg > "$S/vendor_boot/mkbootimg.args"
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/w" -w /w titan2-aosp \
  python3 "${UNPACK#$ROOT/}" --boot_img stock/boot.img --out stock/boot >/dev/null
lz4 -dcf "$S/boot/kernel" > "$S/kernel"
# init_boot: only its ramdisk size matters (the LK 64 MiB ramdisk limit, see build.sh)
cp "$INIT_BOOT" "$S/init_boot.img"
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/w" -w /w titan2-aosp \
  python3 "${UNPACK#$ROOT/}" --boot_img stock/init_boot.img --out stock/init_boot >/dev/null
cp "$S/vendor_boot/dtb" "$S/dtb.dtb"
for f in "$S"/vendor_boot/vendor_ramdisk*; do
  d="$f.d"; mkdir -p "$d"
  (cd "$d" && lz4 -dc "$f" | cpio -idm --quiet 2>/dev/null || true)
done
echo "stock: $(ls "$S")"
