FROM jlesage/baseimage-gui:debian-12-v4.11.3

# K3b is a fuller KDE/Qt burning suite that also drives cdrdao as a backend.
# It pulls a large KDE dependency tree, so this image is much bigger than the
# gcdmaster one.
#   k3b         : the burning suite
#   cdrdao      : DAO / CD-Text engine used by K3b for audio mastering
#   dvd+rw-tools: DVD backend
#   adwaita-qt  : Qt theme so DARK_MODE=1 styles the K3b UI
#   dbus-x11    : provides dbus-run-session for the per-session bus K3b wants
RUN add-pkg k3b cdrdao dvd+rw-tools adwaita-qt dbus-x11

# App start script.
COPY k3b/startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

# Shared device-access env hook (same file the gcdmaster image uses).
COPY rootfs/ /
RUN chmod +x /etc/cont-env.d/SUP_GROUP_IDS_INTERNAL

# App identity shown in the web UI.
RUN set-cont-env APP_NAME "K3b"

VOLUME ["/config", "/storage"]
EXPOSE 5800

LABEL org.opencontainers.image.title="k3b-web" \
      org.opencontainers.image.description="K3b (KDE CD/DVD burning suite) accessible from a web browser. Unofficial, not affiliated with the K3b project." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/nnaqsoft/docker-gcdmaster"
