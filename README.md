# gcdmaster-web

Run **gcdmaster** (the GTK GUI bundled with `cdrdao`) in your web browser. No client
install: open a port, point a browser at it, and you have a full CD authoring desktop
served over [noVNC](https://novnc.com/).

> **Unofficial.** This image is not affiliated with, endorsed by, or supported by the
> cdrdao project, the gcdmaster authors, or the Xfce project. It simply packages the
> upstream Debian binaries behind a browser-based desktop.

This exists to do the things simple web burners (like `jlesage/xfburn`) cannot:
**CD-Text, ISRC codes, pre-emphasis, and exact or zero inter-track gaps (gapless),
written in disc-at-once (DAO) mode.** Those are the touches that make a "real" audio CD,
and they all require a DAO-capable engine driven from a TOC. `cdrdao` is that engine;
gcdmaster is its GUI.

A heavier **K3b** sibling image is also available. See [K3b sibling image](#k3b-sibling-image).

---

## Quick start

### docker run

```bash
docker run -d \
  --name gcdmaster \
  -p 5800:5800 \
  --device /dev/sr0:/dev/sr0 \
  --device /dev/sg0:/dev/sg0 \
  -v "$PWD/config:/config:rw" \
  -v "$PWD/music:/storage:rw" \
  -e ENABLE_CJK_FONT=1 \
  -e DARK_MODE=1 \
  spoisseroux/gcdmaster-web:latest
```

Then open **http://&lt;host&gt;:5800** in a browser.

`/dev/sg0` above is an example. Your SCSI-generic node is almost certainly a different
number. See [Finding your devices](#finding-your-devices) before you run this.

### docker compose

Copy [`docker-compose.example.yml`](docker-compose.example.yml) to `docker-compose.yml`,
edit the two device lines and the image name, then:

```bash
docker compose up -d
```

The image starts and serves the web UI **even with no device mapped**, so you can poke
around the GUI before wiring up a burner. It just cannot burn until a real device is
present.

---

## What this is for

An audio CD stores no track names. It holds only the audio and a table of contents (TOC).
The titles and artist shown on a commercial disc come from **CD-Text** burned onto the
disc itself (or from an online disc-ID lookup). Basic burners cannot write CD-Text and
give no control over the gaps between tracks.

Professional audio-CD authoring needs:

- **CD-Text**: album, artist, and per-track title/performer written to the disc.
- **ISRC** codes: the per-track recording identifiers.
- **Pre-emphasis** flags.
- **Exact or zero inter-track gaps**: a 0-frame gap gives true gapless playback (live
  albums, DJ mixes, classical movements).

All of these require **disc-at-once (DAO)** writing, where the whole disc is written in
one pass from a TOC/cue description. `cdrdao` is the canonical DAO + CD-Text engine, and
gcdmaster is the GUI that drives it.

> Note on CD-Text encoding: per the Red Book spec, CD-Text supports ASCII, ISO-8859-1,
> and MS-JIS (Japanese). `cdrdao` can write these, but how reliably they display depends
> on the player. Many car and hi-fi players show ASCII/Latin-1 cleanly while handling
> Japanese inconsistently.

---

## Device access

Burning needs two host devices, both supplied by you at run time with `--device`:

| Node | Example | Why |
| --- | --- | --- |
| Optical **block** device | `/dev/sr0` | The drive itself. |
| Matching **SCSI-generic** node | `/dev/sg0`, `/dev/sg4`, ... | Raw SCSI command passthrough that `cdrdao` uses for DAO, CD-Text, and precise gaps. The number varies per host, so it is never hardcoded. |

### Finding your devices

On the **host** (not inside the container):

```bash
# Block device(s):
ls -l /dev/sr* /dev/cdrom

# SCSI-generic node(s): match the drive to its sg number
cdrecord -scanbus        # from the wodim/cdrtools package, clearest mapping
# or
wodim --devices
# or
ls -l /dev/sg*
```

Map the `sgN` that corresponds to *your* burner. Mapping the wrong one means cdrdao
talks to the wrong device.

### Group permissions (handled automatically)

The app runs as an unprivileged user inside the container. On the host the device node is
owned by some group (often `cdrom`, but the **GID varies per host**). The image ships an
executable hook at
[`/etc/cont-env.d/SUP_GROUP_IDS_INTERNAL`](rootfs/etc/cont-env.d/SUP_GROUP_IDS_INTERNAL)
that, at startup, detects the GID(s) owning any mapped optical devices and adds them as
supplementary groups for the app user. You normally do not need to configure anything.

**Manual fallback.** If autodetection ever fails, find the GID on the host and set it
yourself:

```bash
ls -ln /dev/sr0          # the 4th column is the owning GID, e.g. 24
docker run ... -e SUP_GROUP_IDS=24 ...
```

**Raw SCSI escalation.** Some hosts/drives require raw SCSI command capability. If DAO or
CD-Text writes fail with permission or SCSI errors *even with the correct group*, add the
capability:

```bash
docker run ... --cap-add SYS_RAWIO ...
```

As a last resort, `--privileged` always works but grants far more than needed. The image
never requires privilege by default.

---

## Environment variables

These are provided by the [`jlesage/baseimage-gui`](https://github.com/jlesage/docker-baseimage-gui)
base image. The full list is in its documentation; the ones most relevant here:

| Variable | Purpose |
| --- | --- |
| `USER_ID` / `GROUP_ID` | UID/GID the app runs as (default 1000). Match the owner of your mapped source files to avoid permission issues. |
| `ENABLE_CJK_FONT=1` | Installs WenQuanYi Zen Hei so Chinese/Japanese/Korean filenames render instead of missing-glyph boxes. |
| `DARK_MODE=1` | Dark web UI and GTK dark theme for gcdmaster. |
| `WEB_FILE_MANAGER=1` | Browser-based file manager into the container, handy for inspecting `/storage`. |
| `WEB_AUDIO=1` | Stream app audio to the browser, to preview tracks. |
| `SUP_GROUP_IDS` | Manual fallback for optical-device group access (see above). |
| `TZ`, `LANG` | Standard timezone and locale. |
| `SECURE_CONNECTION=1` | Serve the UI over HTTPS. |
| `VNC_PASSWORD` | Require a password to connect. |
| `WEB_AUTHENTICATION=1` | Add web-layer login. Recommended before exposing the port beyond localhost. |

### Volumes

| Path | Purpose |
| --- | --- |
| `/config` | Persistent app config and state. Map it to keep settings across restarts. |
| `/storage` | Where you mount your source audio. Mounted read-write so output images and rips can be written back. |

---

## Security note

noVNC gives anyone who can reach the port a full desktop session on the container. Do not
expose port 5800 directly to the internet. Keep it on your LAN or behind a VPN/reverse
proxy, and enable `WEB_AUTHENTICATION=1` plus `SECURE_CONNECTION=1` and `VNC_PASSWORD`
if it must be reachable more widely.

---

## K3b sibling image

[`k3b/`](k3b) builds a sibling image running **K3b**, the fuller KDE burning suite (which
also uses cdrdao as a backend for audio mastering). It is much larger because it pulls a
KDE/Qt dependency tree. Use gcdmaster if you only need audio CD authoring; reach for K3b
if you want a broader data/DVD/ISO toolkit in one GUI.

Build it from the **repo root** (the build context is shared, the Dockerfile lives in
`k3b/`):

```bash
docker build -f k3b/Dockerfile -t k3b-web:local .
```

Run it exactly like the gcdmaster image (same ports, devices, volumes, and env vars).
`adwaita-qt` is included so `DARK_MODE=1` themes the Qt UI, and the start script wraps
K3b in `dbus-run-session` because K3b expects a D-Bus session bus.

---

## Building locally

```bash
# gcdmaster (default), current architecture:
docker build -t gcdmaster-web:local .

# Multi-arch (requires buildx), build and push to your own repo:
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t spoisseroux/gcdmaster-web:latest \
  --push .
```

The base image is pinned to a specific `-vX.Y.Z` in the Dockerfile for reproducible
builds. Bump it deliberately.

### CI

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds for `linux/amd64`
and `linux/arm64`. Pushes/PRs to `main` build only (no push). Pushing a semver tag
(`vX.Y.Z`) builds and pushes to Docker Hub with `:X.Y.Z`, `:X.Y`, `:X`, and `:latest`
tags. Set repo secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` to enable pushing.

---

## Verifying a burn

After burning, confirm the professional touches actually landed:

```bash
# Read the disc TOC back and inspect CD-Text + gaps:
cdrdao read-toc --device /dev/sr0 disc.toc
cat disc.toc        # look for CD_TEXT blocks and per-track START/PREGAP entries
```

A 0-frame pregap (no `PREGAP`/`START` offset between tracks) yields gapless playback. A
CD-Text-capable player should display the album and track titles you set.

---

## License and attribution

- The wrapper in this repo (Dockerfile, scripts, compose, docs, CI) is **MIT**. See
  [`LICENSE`](LICENSE).
- The base image `jlesage/baseimage-gui` is MIT.
- `cdrdao`, `gcdmaster`, and `k3b` are **GPL**. They are installed unmodified from the
  Debian archive, so GPL source availability is satisfied by Debian's published sources.

Full per-component attribution and source pointers are in [`NOTICE`](NOTICE).

### Credits

- Base image: [jlesage/docker-baseimage-gui](https://github.com/jlesage/docker-baseimage-gui)
- Burn engine + GUI: [cdrdao / gcdmaster](https://cdrdao.sourceforge.net/)
- Sibling suite: [K3b](https://apps.kde.org/k3b/)
