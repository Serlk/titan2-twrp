#!/system/bin/sh
# Before TWRP reboots or powers off: give everything on the TEE storage (protect1, mounted by
# prepdecrypt.sh) the labels of the phone's own vendor file_contexts, so that Android's teed can
# open what teed wrote in recovery. TWRP runs it as rebootsystem.sh, rebootrecovery.sh,
# rebootbootloader.sh and poweroff.sh (links to this script).
ctx=/vendor/etc/selinux/vendor_file_contexts
root=/mnt/vendor/protect_f
grep -q " $root " /proc/mounts || exit 0
[ -f $ctx ] || exit 0
# the TEE storage is the tee/ subtree (teed --prot); its "<path regex> <label>" line
grep "^$root/tee" $ctx | sed 's/[[:space:]][[:space:]]*/ /g' | while read re label; do
    dir=${re%%(*}
    [ -e "$dir" ] || continue
    find "$dir" | while read f; do
        [ "$(ls -dZ "$f" | cut -d' ' -f1)" = "$label" ] || chcon "$label" "$f"
    done
done
sync
