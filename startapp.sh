#!/bin/sh
#
# Launch K3b inside the noVNC desktop provided by jlesage/baseimage-gui.
#
# HOME points at the persisted /config volume so K3b settings survive restarts.
export HOME=/config

# K3b warns (and mishandles non-ASCII filenames in data projects) when the locale
# charset is not UTF-8. C.UTF-8 is always present on Debian and needs no locale-gen,
# so set it unless the user supplied their own LANG via the base image.
export LC_ALL="${LC_ALL:-C.UTF-8}"

# K3b is a KDE/Qt app and expects a D-Bus session bus; without one it logs
# "Not connected to D-Bus server" and parts of the UI misbehave. dbus-run-session
# starts a private session bus that lives for as long as K3b runs.
exec dbus-run-session -- /usr/bin/k3b
