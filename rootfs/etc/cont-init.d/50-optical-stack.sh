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
#
# Test for a LIVE BUS, not for the socket file. /run survives `docker restart`,
# so after any restart the socket from the previous boot is still sitting there
# while nothing is listening on it. The old check was `[ ! -S socket ]`, which
# saw that stale file, concluded the bus was up, and skipped starting it. udisksd
# then started against a dead bus and exited, so Solid enumerated nothing and K3b
# reported "no optical drive" on every boot after the first.
#
# That is exactly what happened here: this image worked when first started
# 2026-06-17 and broke silently on the 2026-07-28 restart, with the init log
# still saying "udisksd started" both times. The symptom looked like a hardware
# or passthrough problem and was neither.
mkdir -p /run/dbus
dbus-uuidgen --ensure >/dev/null 2>&1

bus_alive() {
    dbus-send --system --dest=org.freedesktop.DBus --print-reply \
        /org/freedesktop/DBus org.freedesktop.DBus.ListNames >/dev/null 2>&1
}

if bus_alive; then
    log "system D-Bus already running"
else
    # Clear the corpse from the previous boot, or dbus-daemon refuses to bind.
    rm -f /run/dbus/system_bus_socket /run/dbus/pid
    if dbus-daemon --system --fork >/dev/null 2>&1 && bus_alive; then
        log "system D-Bus started"
    else
        log "system D-Bus FAILED to start: K3b will not detect any drive"
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
#
# VERIFY IT ANSWERS, do not just launch it. Backgrounding a process always
# "succeeds": udisksd exits immediately when the system bus is missing, and the
# old code still logged "udisksd started". A log line that cannot report its own
# failure is worse than no log line, because it sends you looking at the
# hardware. Ask udisks2 the same question K3b asks and report what comes back.
UDISKSD=
for p in /usr/libexec/udisks2/udisksd /usr/lib/udisks2/udisksd; do
    [ -x "$p" ] && UDISKSD="$p" && break
done

if [ -n "$UDISKSD" ]; then
    "$UDISKSD" --no-debug >/dev/null 2>&1 &
    # it needs a moment to claim its bus name before it can answer
    i=0
    while [ $i -lt 10 ]; do
        drives=$(dbus-send --system --print-reply --dest=org.freedesktop.UDisks2 \
                   /org/freedesktop/UDisks2 \
                   org.freedesktop.DBus.ObjectManager.GetManagedObjects 2>/dev/null \
                 | grep -c "/drives/")
        [ "${drives:-0}" -gt 0 ] && break
        i=$((i + 1)); sleep 1
    done
    if [ "${drives:-0}" -gt 0 ]; then
        log "udisksd running, udisks2 reports $drives drive object(s)"
    else
        log "udisksd NOT answering on the system bus: K3b will show no drive"
    fi
else
    log "udisksd binary not found: K3b will show no drive"
fi

# Never fail the init sequence over optional drive-detection plumbing.
exit 0
