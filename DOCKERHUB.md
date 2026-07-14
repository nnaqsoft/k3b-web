# k3b-web

**[K3b](https://apps.kde.org/k3b/)**, the full KDE CD / DVD / Blu-ray burning suite, in your
web browser, served over noVNC. No client install: open port 5800 and point a browser at it.

Source, issues, and full docs: **https://github.com/nnaqsoft/k3b-web**

> **Unofficial.** Not affiliated with or endorsed by the K3b / KDE projects. This image
> packages the upstream Debian binaries behind a browser-based desktop, in the style of
> [jlesage](https://github.com/jlesage)'s GUI images.

K3b is the de facto standard burning suite on Linux. This image puts it on a headless box
(a NAS, a home server, an LXC with the optical drive passed through) and lets you drive it
from any browser on your network.

## What it can do

- **Burn audio CDs** with **CD-Text, ISRC, pre-emphasis, and exact or zero inter-track gaps
  (gapless)** in **disc-at-once (DAO)** mode via the `cdrdao` backend. The touches simple
  burners cannot do.
- **Burn data CDs, DVDs (single and dual-layer), and Blu-ray**, plus ISO images, disc
  copies, multisession, and bootable discs.
- **Rip audio CDs** with online (CDDB) track-name lookup and built-in encoders: **FLAC,
  MP3 (LAME), Ogg Vorbis, Opus, WavPack, and WAVE**. The encoder CLIs are baked in, so they
  appear in K3b's rip "Filetype" list automatically.
- **Blank and format** rewritable media (CD-RW, DVD-RW), and verify writes.

K3b copies and burns DVDs but does **not** transcode video DVDs to files (that is a
HandBrake or MakeMKV job). Reading encrypted commercial DVDs also needs `libdvdcss`, which
is not in Debian and is not bundled here.

## Quick start

### docker run

```bash
docker run -d \
  --name k3b \
  -p 5800:5800 \
  --privileged \
  --device /dev/sr0:/dev/sr0 \
  --device /dev/sg0:/dev/sg0 \
  -v "$PWD/config:/config:rw" \
  -v "$PWD/media:/storage:rw" \
  -e DARK_MODE=1 \
  spoisseroux/k3b-web:latest
```

Open **http://&lt;host&gt;:5800**. The `/dev/sg0` value is an example; find yours with
`cdrecord -scanbus` or `ls -l /dev/sg*` and map the node that matches your burner.

### docker compose

```yaml
services:
  k3b:
    image: spoisseroux/k3b-web:latest
    container_name: k3b
    privileged: true            # required for drive detection (see below)
    ports:
      - "5800:5800"
    devices:
      - /dev/sr0:/dev/sr0       # your block device
      - /dev/sg0:/dev/sg0       # your matching SCSI-generic node
    volumes:
      - ./config:/config:rw
      - ./media:/storage:rw
    environment:
      - DARK_MODE=1
      - WEB_FILE_MANAGER=1
    restart: unless-stopped
```

The image starts and serves the web UI even with no device mapped, so you can look around
before wiring up a burner. K3b just reports "No optical drive found" until a drive is
present.

## Devices and privileges

Map both the optical **block** device (`/dev/srN`) and its matching **SCSI-generic** node
(`/dev/sgN`). The sg node is required for DAO / CD-Text / gap control and its number varies
per host, so find it with `cdrecord -scanbus`, `wodim --devices`, or `ls -l /dev/sg*`.

**`--privileged` is required for K3b to detect the drive.** K3b does not scan `/dev` itself.
It lists drives through KDE Solid, whose only optical backend talks to **udisks2** over the
system D-Bus, and udisks2 only recognises a node as optical after **udev** has stamped it
with `ID_CDROM`. A bare container has none of that. This image starts udev, a system D-Bus,
and `udisksd` at boot so K3b can enumerate the drive, and udev needs the privilege to write
`/sys`. Without it the web UI still serves but no drive appears. To scope down, the minimum
is `--cap-add SYS_ADMIN` plus the device (and often `--cap-add SYS_RAWIO` for raw SCSI).

Device **group permissions** are detected and applied automatically. If autodetection ever
fails, set `-e SUP_GROUP_IDS=<gid>` (the owning GID from `ls -ln /dev/sr0`).

The image ships `wodim` and `cdrdao` **setuid root** (mode `4711`) so they can lock their
burn buffer in RAM; otherwise burns fail with `Cannot raise RLIMIT_MEMLOCK`. This is exactly
what `k3bsetup` configures on a desktop install. `growisofs` is left unprivileged.

## Environment variables

Provided by the [`jlesage/baseimage-gui`](https://github.com/jlesage/docker-baseimage-gui)
base image. Most relevant here:

| Variable | Purpose |
| --- | --- |
| `USER_ID` / `GROUP_ID` | App UID/GID (default 1000); match your source-file owner. |
| `DARK_MODE=1` | Dark web UI and dark Qt theme for K3b. |
| `ENABLE_CJK_FONT` | Not required: the Noto family (Latin, Cyrillic, Greek, Arabic, Hebrew, Indic, CJK, emoji) and a UTF-8 locale are baked in, so any-script metadata and filenames render. |
| `WEB_FILE_MANAGER=1` | Browse `/storage` from the browser. |
| `WEB_AUDIO=1` | Stream app audio to the browser, to preview tracks. |
| `SUP_GROUP_IDS` | Manual device-group fallback. |
| `TZ`, `LANG` | Timezone and locale. Charset defaults to `C.UTF-8`. |
| `SECURE_CONNECTION=1`, `VNC_PASSWORD`, `WEB_AUTHENTICATION=1` | Hardening for exposed deployments. |

**Volumes:** `/config` (persistent app settings), `/storage` (source files and rip/image
output, read-write).

## Dark mode

The UI ships light by default. Set `DARK_MODE=1` to switch both the noVNC web shell and the
K3b Qt interface to dark (the image includes `adwaita-qt`, which themes the Qt side). The
value is read at container start, so changing it means recreating the container.

## Languages and fonts

The image bakes in the Noto font family (Latin and Latin-extended, Cyrillic, Greek, Arabic,
Hebrew, Indic, full CJK, and color emoji) plus a generated `en_US.UTF-8` locale. CDDB
results, tags, and filenames in mixed scripts render as real glyphs instead of
missing-glyph boxes. You do not need `ENABLE_CJK_FONT`.

## Verifying a burn

After burning an audio CD, read the disc back and check the CD-Text and gaps:

```bash
cdrdao read-toc --device /dev/sr0 disc.toc
cat disc.toc        # look for CD_TEXT blocks and per-track START/PREGAP entries
```

A 0-frame pregap yields gapless playback. A CD-Text-capable player shows the titles you set.

## Security

noVNC exposes a full desktop session to anyone who can reach the port. Do not expose port
5800 directly to the internet. Keep it on your LAN or behind a VPN, and enable
`WEB_AUTHENTICATION=1` plus `SECURE_CONNECTION=1` and `VNC_PASSWORD` if it must be reachable
more widely.

## Tags

- `latest` tracks the newest release.
- `X.Y.Z`, `X.Y`, `X` semver tags (for example `1.2.1`, `1.2`, `1`). Pin a specific `X.Y.Z`
  for reproducible deployments.
- Multi-arch: `linux/amd64` and `linux/arm64`.

## License and credits

The wrapper (Dockerfile, scripts, docs) is **MIT**. Bundled `k3b`, `cdrdao`, `wodim`, and
`dvd+rw-tools` are **GPL**, installed unmodified from Debian (source available via Debian).
Full attribution is in the repository `LICENSE` and `NOTICE`.

- Base image: [jlesage/docker-baseimage-gui](https://github.com/jlesage/docker-baseimage-gui)
- Burning suite: [K3b](https://apps.kde.org/k3b/)
- Audio mastering backend: [cdrdao](https://cdrdao.sourceforge.net/)
