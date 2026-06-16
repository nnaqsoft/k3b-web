FROM jlesage/baseimage-gui:debian-12-v4.11.3

# Burn engine + GUI, plus optional extra backends for DVD and CD-RW media.
#   cdrdao   : disc-at-once burn engine (CD-Text, ISRC, precise/zero gaps)
#   gcdmaster: the GTK GUI for cdrdao (depends on cdrdao, listed explicitly)
#   dvd+rw-tools / wodim: broader media support (DVD, plain data CD)
RUN add-pkg gcdmaster cdrdao dvd+rw-tools wodim

# App start script.
COPY startapp.sh /startapp.sh
RUN chmod +x /startapp.sh

# Files copied into the container image (device-access env hook, etc.).
COPY rootfs/ /
RUN chmod +x /etc/cont-env.d/SUP_GROUP_IDS_INTERNAL

# App identity shown in the web UI.
RUN set-cont-env APP_NAME "gcdmaster"

# Standard mount points this image expects.
#   /config  : persistent app config and state
#   /storage : user source audio files (read-write so output images can be written)
VOLUME ["/config", "/storage"]

# noVNC web UI.
EXPOSE 5800

# OCI image metadata. Replace the URLs with your published repo at build time.
LABEL org.opencontainers.image.title="gcdmaster-web" \
      org.opencontainers.image.description="gcdmaster (cdrdao GUI) accessible from a web browser. Unofficial, not affiliated with the cdrdao or gcdmaster projects." \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/nnaqsoft/docker-gcdmaster"
