#!/bin/sh
#
# /etc/cont-init.d/50-optical-stack.sh  (must be executable)
#
# K3b lists optical drives through KDE Solid, whose only optical backend talks to
# udisks2 over the SYSTEM D-Bus. udisks2 in turn only classifies a node as an
# optical drive once udev has processed it and stamped the ID_CDROM property. None
# of that machinery exists in a bare container, which is why K3b otherwise reports
# "No optical drive found" even though the device node is fully reachable.
#
# This script brings that stack up at startup: system D-Bus, udev (so the mapped
# drive gets ID_CDROM), then udisksd. It needs the container to run privileged
# (or with CAP_SYS_ADMIN and the device mapped) so udevd can write to /sys and the
# udev database.
#
# It is deliberately best-effort: if a step fails (for example when the container
# is run unprivileged) it logs and continues so the web UI still serves. Burning
# and ripping drive the device node directly (cdrecord/cdrdao/growisofs/cdparanoia)
# and do not depend on this; only K3b's drive auto-detection does.

log() { echo "[optical-stack] $*"; }

# The baseimage rebuilds /etc/passwd and /etc/group at startup and drops the
# 'messagebus' user/group that the dbus package created, so recreate them here or
# the system bus refuses to start (it drops privileges to that user).
if ! getent group messagebus >/dev/null 2>&1; then
    addgroup --system messagebus >/dev/null 2>&1 && log "recreated messagebus group"
fi
if ! getent passwd messagebus >/dev/null 2>&1; then
    adduser --system --no-create-home --ingroup messagebus messagebus >/dev/null 2>&1 \
        && log "recreated messagebus user"
fi

# 1. System D-Bus.
mkdir -p /run/dbus
dbus-uuidgen --ensure >/dev/null 2>&1
if [ ! -S /run/dbus/system_bus_socket ]; then
    if dbus-daemon --system --fork >/dev/null 2>&1; then
        log "system D-Bus started"
    else
        log "system D-Bus failed to start"
    fi
fi

# 2. udev daemon + coldplug, so the mapped drive gets ID_CDROM and friends.
if [ -x /lib/systemd/systemd-udevd ]; then
    if /lib/systemd/systemd-udevd --daemon >/dev/null 2>&1; then
        log "udevd started"
        udevadm trigger >/dev/null 2>&1
        udevadm settle -t 15 >/dev/null 2>&1
    else
        log "udevd failed to start (is the container privileged?)"
    fi
fi

# 3. udisks2 daemon, which enumerates drives for Solid / K3b.
if [ -x /usr/libexec/udisks2/udisksd ]; then
    /usr/libexec/udisks2/udisksd --no-debug >/dev/null 2>&1 &
    log "udisksd started"
elif [ -x /usr/lib/udisks2/udisksd ]; then
    /usr/lib/udisks2/udisksd --no-debug >/dev/null 2>&1 &
    log "udisksd started"
fi

# Never fail the init sequence over optional drive-detection plumbing.
exit 0
