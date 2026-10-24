#!/usr/bin/env bash
# Try the TWRP vendor_boot on the phone (slot a), with a way back.
#   scripts/flash-test.sh check    adb + root: compare the phone's vendor_boot_a with stock/vendor_boot.img
#   scripts/flash-test.sh flash    adb reboot bootloader, fastboot flash vendor_boot_a out/vendor_boot-twrp.img
#   scripts/flash-test.sh restore  fastboot flash vendor_boot_a stock/vendor_boot.img
# Recovery: Vol Up at power-on (LK), or "adb reboot recovery" from Android.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
T2=$(cd "$ROOT/../titan2-linux" && pwd)
ADB=${ADB:-$T2/tools/platform-tools/adb}
FB=${FASTBOOT:-$T2/tools/platform-tools/fastboot}
case "${1:-}" in
check)
  want=$(sha256sum < "$ROOT/stock/vendor_boot.img" | cut -d' ' -f1)
  have=$("$ADB" shell "su -c 'sha256sum /dev/block/by-name/vendor_boot_a'" | cut -d' ' -f1)
  slot=$("$ADB" shell getprop ro.boot.slot_suffix)
  echo "slot $slot; vendor_boot_a $have"
  [ "$have" = "$want" ] && echo "= stock/vendor_boot.img: the PLATFORM fragment is the phone's own" \
    || { echo "DIFFERS from stock/vendor_boot.img: extract it from the phone first" >&2; exit 1; } ;;
flash)
  "$ADB" reboot bootloader || true
  "$FB" getvar product >/dev/null 2>&1   # fastboot waits for the device
  [ "$("$FB" getvar current-slot 2>&1 | sed -n 's/^current-slot: //p')" = a ] || { echo "not slot a" >&2; exit 1; }
  "$FB" flash vendor_boot_a "$ROOT/out/vendor_boot-twrp.img"
  echo "flashed; hold Vol Up and press Power, or: $FB reboot (Android) then adb reboot recovery" ;;
restore)
  "$FB" flash vendor_boot_a "$ROOT/stock/vendor_boot.img" ;;
*) sed -n 2,6p "$0"; exit 1 ;;
esac
