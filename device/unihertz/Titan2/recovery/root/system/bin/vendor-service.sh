#!/system/bin/sh
# Run a service of the phone's own vendor partition the way its vendor init scripts define it:
#   vendor-service.sh <service name>
# The command line is read from /vendor/etc/init/*.rc at run time, so nothing of the vendor
# configuration is part of the recovery. init starts this script as the recovery service
# (init.recovery.mt6878.rc gives user, group and capabilities); the script then becomes the
# vendor program, with the vendor libraries first in the search path.
name=$1
for rc in /vendor/etc/init/*.rc; do
    # "service <name> <path> <args...>", continued over lines ending in a backslash
    cmd=$(sed -n "/^service $name /{
:a
/\\\\\$/{
N
ba
}
p
q
}" "$rc" | sed 's/\\$//; s/^service [^ ]* //' | tr '\n' ' ')
    [ -n "$cmd" ] && break
done
if [ -z "$cmd" ]; then
    echo "vendor-service: no service $name in /vendor/etc/init" > /dev/kmsg
    exit 1
fi
export LD_LIBRARY_PATH=/vendor/lib64:/system/lib64
# word splitting of the command line is intended
exec $cmd
