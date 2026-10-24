#!/system/bin/sh
# Titan 2: start the TrustKernel TEE services from the phone's own vendor partition before TWRP
# decrypts /data (run by TWRP, patches/bootable_recovery/0001). Nothing from the vendor is in the
# recovery ramdisk: /vendor is the real partition, mounted here and left mounted.
#
# teed is started the way Android starts it before /data is decrypted: vendor.trustkernel.fs.state
# is never set to "ready" here, so teed does not touch its storage on /data.
log() { echo "prepdecrypt: $*"; echo "prepdecrypt: $*" > /dev/kmsg; }

slot=$(getprop ro.boot.slot_suffix)
if ! grep -q " /vendor " /proc/mounts; then
    mount -t erofs -o ro "/dev/block/mapper/vendor$slot" /vendor || { log "no vendor$slot"; exit 1; }
fi
[ -x /vendor/bin/teed ] || { log "no /vendor/bin/teed"; exit 1; }

mkdir -p /mnt/vendor/protect_f
grep -q " /mnt/vendor/protect_f " /proc/mounts ||
    mount -t ext4 -o noatime,nosuid,nodev /dev/block/by-name/protect1 /mnt/vendor/protect_f

# the recovery ueventd leaves these root-only; Android gives them to system
for d in /dev/tkcore_admin /dev/tkcore_client /dev/tkcore_fp /dev/rpmb0; do
    [ -e $d ] && chown system:system $d && chmod 0660 $d
done

wait_prop() { # name value seconds
    i=0
    while [ "$(getprop $1)" != "$2" ] && [ $i -lt $(($3 * 10)) ]; do sleep 0.1; i=$((i + 1)); done
    [ "$(getprop $1)" = "$2" ]
}

start titan2.teed
wait_prop vendor.trustkernel.ready true 10 || log "teed not ready"
start titan2.keymint
start titan2.gatekeeper
wait_prop init.svc.titan2.keymint running 5 || log "keymint not running"
wait_prop init.svc.titan2.gatekeeper running 5 || log "gatekeeper not running"
# the services register with servicemanager right after start
sleep 1
log "teed=$(getprop init.svc.titan2.teed) keymint=$(getprop init.svc.titan2.keymint) gatekeeper=$(getprop init.svc.titan2.gatekeeper)"
