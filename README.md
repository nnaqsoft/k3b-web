# k3b-web

Run **[K3b](https://apps.kde.org/k3b/)**, the full KDE CD / DVD / Blu-ray burning suite,
in your web browser. No client install: open a port, point a browser at it, and you have a
complete optical-disc authoring desktop served over [noVNC](https://novnc.com/).

> **Unofficial.** This image is not affiliated with, endorsed by, or supported by the K3b
> or KDE projects. It simply packages the upstream Debian binaries behind a browser-based
> desktop, in the style of [jlesage](https://github.com/jlesage)'s GUI images.

K3b is the de facto standard burning suite on Linux. This image puts it on a headless box
(a NAS, a home server, an LXC with the optical drive passed through) and lets you drive it
from any browser on your network.

## What it can do

- **Burn audio CDs** with **CD-Text, ISRC, pre-emphasis, and exact or zero inter-track
  gaps (gapless)**, written in **disc-at-once (DAO)** mode via the `cdrdao` backend. These
  are the touches simple burners cannot do.
- **Burn data CDs, DVDs (single and dual-layer), and Blu-ray**, plus ISO images, disc
  copies, multisession, and bootable discs.
- **Rip audio CDs** with online (CDDB) track-name lookup and built-in encoders (FLAC, MP3,
  Ogg, WAV).
- **Blank and format** rewritable media (CD-RW, DVD-RW), and verify writes.

> Note on CD-Text encoding: per the Red Book spec, CD-Text supports ASCII, ISO-8859-1, and
> MS-JIS (Japanese). The cdrdao backend can write these, but how reliably they display
> depends on the player. Many car and hi-fi players show ASCII/Latin-1 cleanly while
> handling Japanese inconsistently.

---

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

Then open **http://&lt;host&gt;:5800** in a browser.

`--privileged` is required for K3b to detect the drive (see
[Drive detection requires elevated privileges](#drive-detection-requires-elevated-privileges-important)).
`/dev/sg0` above is an example. Your SCSI-generic node is almost certainly a different
number. See [Finding your devices](#finding-your-devices) before you run this.

### docker compose

Copy [`docker-compose.example.yml`](docker-compose.example.yml) to `docker-compose.yml`,
edit the two device lines, then:

```bash
docker compose up -d
```

The image starts and serves the web UI **even with no device mapped**, so you can poke
around the UI before wiring up a burner. K3b will simply report "No optical drive found"
until a real device is present.

---

## Device access

Burning needs two host devices, both supplied by you at run time with `--device`:

| Node | Example | Why |
| --- | --- | --- |
| Optical **block** device | `/dev/sr0` | The drive itself. |
| Matching **SCSI-generic** node | `/dev/sg0`, `/dev/sg4`, ... | Raw SCSI command passthrough used for DAO, CD-Text, and precise gaps. The number varies per host, so it is never hardcoded. |

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

Map the `sgN` that corresponds to *your* burner. Mapping the wrong one means the backend
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

### Drive detection requires elevated privileges (important)

K3b does not scan `/dev` itself. It lists drives through KDE Solid, whose only optical
backend talks to **udisks2** over the system D-Bus, and udisks2 only recognises a node as
an optical drive after **udev** has processed it and set the `ID_CDROM` property. A bare
container has none of that, which is why K3b would otherwise report "No optical drive
found" even when the device is fully reachable.

This image solves that: at startup it runs `udev`, a system D-Bus, and `udisksd`
(see [`/etc/cont-init.d/50-optical-stack.sh`](rootfs/etc/cont-init.d/50-optical-stack.sh)),
so K3b can enumerate the drive. udevd needs to write to `/sys` and the udev database, so
**the container must run with elevated privileges:**

```bash
docker run ... --privileged ... spoisseroux/k3b-web:latest
```

`--privileged` is the simple, reliable option (and is the norm when an optical drive is
passed through, e.g. inside a privileged LXC). If you prefer to scope it down, the minimum
that works is `--cap-add SYS_ADMIN` plus the mapped device; some hosts/drives also need
`--cap-add SYS_RAWIO` for raw SCSI writes. If you run unprivileged, the web UI still serves
and the startup script logs that udevd could not start, but K3b will not detect the drive.

> Lower-privilege alternative: instead of running udevd in the container, bind-mount the
> host's already-populated udev database read-only with `-v /run/udev:/run/udev:ro` (the
> host must have processed the drive). The startup script still brings up the system D-Bus
> and udisksd, which then read the host's udev data.

---

## Environment variables

These are provided by the [`jlesage/baseimage-gui`](https://github.com/jlesage/docker-baseimage-gui)
base image. The full list is in its documentation; the ones most relevant here:

| Variable | Purpose |
| --- | --- |
| `USER_ID` / `GROUP_ID` | UID/GID the app runs as (default 1000). Match the owner of your mapped source files to avoid permission issues. |
| `ENABLE_CJK_FONT` | Not required: the WenQuanYi Zen Hei CJK font is baked into this image, so Chinese/Japanese/Korean filenames render out of the box. The base-image variable still exists but you do not need to set it. |
| `DARK_MODE=1` | Dark web UI and dark Qt theme for K3b (via `adwaita-qt`). |
| `WEB_FILE_MANAGER=1` | Browser-based file manager into the container, handy for inspecting `/storage`. |
| `WEB_AUDIO=1` | Stream app audio to the browser, to preview tracks. |
| `SUP_GROUP_IDS` | Manual fallback for optical-device group access (see above). |
| `TZ`, `LANG` | Standard timezone and locale. The image defaults the charset to `C.UTF-8` if you do not set `LANG`. |
| `SECURE_CONNECTION=1` | Serve the UI over HTTPS. |
| `VNC_PASSWORD` | Require a password to connect. |
| `WEB_AUTHENTICATION=1` | Add web-layer login. Recommended before exposing the port beyond localhost. |

### Volumes

| Path | Purpose |
| --- | --- |
| `/config` | Persistent app config and state. Map it to keep settings across restarts. |
| `/storage` | Where you mount source files and where rips/images are written. Mounted read-write. |

---

## Security note

noVNC gives anyone who can reach the port a full desktop session on the container. Do not
expose port 5800 directly to the internet. Keep it on your LAN or behind a VPN/reverse
proxy, and enable `WEB_AUTHENTICATION=1` plus `SECURE_CONNECTION=1` and `VNC_PASSWORD` if
it must be reachable more widely.

---

## A note on the optical drive

An optical drive is a single physical device with exclusive access during any burn or rip.
You can map the same drive into more than one container, but only one process can use it at
a time; a second one will get a "device busy" error. Run a single burning container against
a given drive.

---

## Building locally

```bash
# Current architecture:
docker build -t k3b-web:local .

# Multi-arch (requires buildx), build and push to your own repo:
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t spoisseroux/k3b-web:latest \
  --push .
```

The base image is pinned to a specific `-vX.Y.Z` in the Dockerfile for reproducible builds.
Bump it deliberately.

### CI

[`.github/workflows/build.yml`](.github/workflows/build.yml) builds for `linux/amd64` and
`linux/arm64`. Pushes/PRs to `main` build only (no push). Pushing a semver tag (`vX.Y.Z`)
builds and pushes to Docker Hub with `:X.Y.Z`, `:X.Y`, `:X`, and `:latest` tags. Set repo
secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` to enable pushing.

---

## Verifying a burn

After burning an audio CD, confirm the professional touches actually landed:

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
- `k3b`, `cdrdao`, `wodim`, and `dvd+rw-tools` are **GPL**. They are installed unmodified
  from the Debian archive, so GPL source availability is satisfied by Debian's published
  sources.

Full per-component attribution and source pointers are in [`NOTICE`](NOTICE).

### Credits

- Base image: [jlesage/docker-baseimage-gui](https://github.com/jlesage/docker-baseimage-gui)
- Burning suite: [K3b](https://apps.kde.org/k3b/)
- Audio mastering backend: [cdrdao](https://cdrdao.sourceforge.net/)
