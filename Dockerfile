FROM jlesage/baseimage-gui:debian-12-v4.11.3

# K3b is KDE's full CD/DVD/Blu-ray burning suite. It drives several backends:
#   k3b          : the burning suite (GUI)
#   cdrdao       : disc-at-once engine used for audio mastering (CD-Text, gapless gaps)
#   wodim        : data-CD backend (cdrecord)
#   dvd+rw-tools : DVD / Blu-ray backend (growisofs)
#   libburn / cdrskin come in via k3b's dependencies
# Theming / session helpers:
#   adwaita-qt   : Qt theme so DARK_MODE=1 styles the K3b UI
#   dbus-x11     : provides dbus-run-session for the per-session bus K3b expects
RUN add-pkg k3b cdrdao dvd+rw-tools wodim adwaita-qt dbus-x11

# App start script.
COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

# Files copied into the container image (device-access env hook, etc.).
COPY rootfs/ /
RUN chmod +x /etc/cont-env.d/SUP_GROUP_IDS_INTERNAL

# App identity shown in the web UI.
RUN set-cont-env APP_NAME "K3b"

# Standard mount points this image expects.
#   /config  : persistent app config and state
#   /storage : user source/output files (read-write so rips and images can be written)
VOLUME ["/config", "/storage"]

# noVNC web UI.
EXPOSE 5800

# OCI image metadata.
LABEL org.opencontainers.image.title="k3b-web" \
      org.opencontainers.image.description="K3b (KDE CD/DVD burning suite) accessible from a web browser. Unofficial, not affiliated with the K3b project." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/nnaqsoft/docker-k3b"
