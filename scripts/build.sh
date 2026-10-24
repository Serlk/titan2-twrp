#!/usr/bin/env bash
# Build TWRP for the Titan 2. Writes
#  - out/twrp-titan2-recovery.lz4: the TWRP ramdisk (the RECOVERY fragment), publishable;
#  - out/vendor_boot-twrp.img: YOUR vendor_boot (stock/, from scripts/extract-stock.sh: header,
#    PLATFORM fragment, dtb) with that fragment. It carries stock files: never publish it.
#   scripts/build.sh            build and pack
#   PACK_ONLY=1 scripts/build.sh  repack from the last build
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
S=$ROOT/stock
DEV=$ROOT/src/device/unihertz/Titan2
[ -f "$S/kernel" ] || "$ROOT/scripts/extract-stock.sh"

if [ -z "${PACK_ONLY:-}" ]; then
  # the device tree goes into the source tree as a copy; prebuilt/ (stock kernel, dtb) is added
  # to the copy only
  # our patches to the TWRP sources (patches/<project path with _ for />/*.patch), applied once
  for d in "$ROOT"/patches/*/; do
    proj=$(basename "$d" | tr _ /)
    for p in "$d"*.patch; do
      git -C "$ROOT/src/$proj" apply --reverse --check "$p" 2>/dev/null && continue
      git -C "$ROOT/src/$proj" apply "$p" && echo "applied $(basename "$p")"
    done
  done
  rm -rf "$DEV"; mkdir -p "$DEV/prebuilt"
  cp -a "$ROOT/device/unihertz/Titan2/." "$DEV/"
  # logd aborts without the task profiles (AOSP system/core); not in the TWRP ramdisk
  cp "$ROOT/src/system/core/libprocessgroup/profiles/task_profiles.json" "$DEV/recovery/root/system/etc/"
  cp "$S/kernel" "$DEV/prebuilt/kernel"; mkdir -p "$DEV/prebuilt/dtb"; cp "$S/dtb.dtb" "$DEV/prebuilt/dtb/"
  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/home/builder \
    -v "$ROOT/work/home:/home/builder" -v "$ROOT/src:/src" -w /src titan2-aosp bash -ec '
export ALLOW_MISSING_DEPENDENCIES=true LC_ALL=C
source build/envsetup.sh >/dev/null
lunch twrp_Titan2-ap2a-eng
m -j${JOBS:-12} vendorbootimage
' 2>&1 | tee "$ROOT/work/build.log" | grep -E "^(FAILED|error|ninja: build stopped)|#### |vendor_boot.img" || true
fi

IMG=$ROOT/src/out/target/product/Titan2/vendor_boot.img
[ -f "$IMG" ] || { echo "no $IMG, see work/build.log" >&2; exit 1; }
W=$ROOT/work/pack; rm -rf "$W"; mkdir -p "$W" "$ROOT/out"
U=src/system/tools/mkbootimg
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT:/w" -w /w titan2-aosp bash -euc "
python3 $U/unpack_bootimg.py --boot_img src/out/target/product/Titan2/vendor_boot.img --out work/pack/twrp >/dev/null
# the stock image, TWRP ramdisk instead of its RECOVERY fragment (vendor_ramdisk01)
args=\$(sed 's|stock/vendor_boot/vendor_ramdisk01|work/pack/twrp/vendor-ramdisk-by-name/ramdisk_recovery|' stock/vendor_boot/mkbootimg.args)
eval python3 $U/mkbootimg.py \$args --vendor_boot out/vendor_boot-twrp.img
python3 $U/unpack_bootimg.py --boot_img out/vendor_boot-twrp.img --out work/pack/check | grep -E 'size|name|type'
"
# LK copies every vendor ramdisk fragment, the init_boot ramdisk and bootconfig into its 64 MiB
# mb_ramdisk region, in a normal boot too (sum + 0x400 <= 64 MiB, else an ASSERT and no boot).
# INIT_BOOT_RAMDISK_SIZE: the ramdisk size of the init_boot flashed on the phone (a patched root
# init_boot is bigger than stock); default: stock plus 2 MiB for root.
vr=$(( $(stat -c%s "$S/vendor_boot/vendor_ramdisk00") + $(stat -Lc%s "$W/twrp/vendor-ramdisk-by-name/ramdisk_recovery") ))
ib=${INIT_BOOT_RAMDISK_SIZE:-$(( $(stat -c%s "$S/boot/ramdisk" 2>/dev/null || echo 0) + 2*1024*1024 ))}
[ -f "$S/init_boot/ramdisk" ] && ib=${INIT_BOOT_RAMDISK_SIZE:-$(( $(stat -c%s "$S/init_boot/ramdisk") + 2*1024*1024 ))}
total=$(( vr + ib + 0x400 )); limit=$(( 64*1024*1024 ))
echo "ramdisks: vendor $vr + init_boot $ib + 0x400 = $total of $limit (free $(( (limit-total)/1024 )) KiB)"
[ "$total" -le "$limit" ] || { echo "TOO BIG for LK mb_ramdisk: the phone would not boot at all" >&2; rm -f "$ROOT/out/vendor_boot-twrp.img"; exit 1; }
# the TWRP fragment alone (TWRP/AOSP and this repository only): what a release publishes
cp -L "$W/twrp/vendor-ramdisk-by-name/ramdisk_recovery" "$ROOT/out/twrp-titan2-recovery.lz4"
ls -la "$ROOT/out/vendor_boot-twrp.img" "$ROOT/out/twrp-titan2-recovery.lz4"
