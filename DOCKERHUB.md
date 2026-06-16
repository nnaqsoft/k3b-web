# gcdmaster-web

**gcdmaster** (the GTK GUI bundled with `cdrdao`) in your web browser, served over noVNC.
No client install: open port 5800 and point a browser at it.

> **Unofficial.** Not affiliated with or endorsed by the cdrdao / gcdmaster projects.
> This image packages the upstream Debian binaries behind a browser-based desktop.

This does what simple web burners cannot: **CD-Text, ISRC, pre-emphasis, and exact or
zero inter-track gaps (gapless)**, written in **disc-at-once (DAO)** mode. `cdrdao` is the
DAO + CD-Text engine; gcdmaster is its GUI.

A heavier **K3b** sibling (`k3b/Dockerfile`) is in the same repo.

## Quick start

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

Open **http://&lt;host&gt;:5800**. The `/dev/sg0` value is an example; find yours with
`cdrecord -scanbus` or `ls -l /dev/sg*` and map the node that matches your burner.

## Devices

Map both the block device (`/dev/srN`) and its matching SCSI-generic node (`/dev/sgN`).
The sg node is required for DAO/CD-Text/gap control and its number varies per host.
Device group permissions are detected and applied automatically; if that fails, set
`-e SUP_GROUP_IDS=<gid>` (from `ls -ln /dev/sr0`). If DAO/CD-Text writes hit SCSI
permission errors anyway, add `--cap-add SYS_RAWIO`.

## Key environment variables

| Variable | Purpose |
| --- | --- |
| `USER_ID` / `GROUP_ID` | App UID/GID (default 1000); match your source-file owner. |
| `ENABLE_CJK_FONT=1` | Render CJK (e.g. Japanese) filenames. |
| `DARK_MODE=1` | Dark web UI and GTK theme. |
| `WEB_FILE_MANAGER=1` | Browse `/storage` from the browser. |
| `SUP_GROUP_IDS` | Manual device-group fallback. |
| `WEB_AUTHENTICATION=1`, `SECURE_CONNECTION=1`, `VNC_PASSWORD` | Hardening for exposed deployments. |

Volumes: `/config` (persistent settings), `/storage` (your source audio, read-write).

**Security:** noVNC exposes a full desktop. Keep port 5800 on your LAN or behind a VPN,
and enable web authentication before exposing it more widely.

## License

Wrapper is MIT. Bundled `cdrdao` / `gcdmaster` / `k3b` are GPL, installed unmodified from
Debian (source available via Debian). Full details in the repo `LICENSE` and `NOTICE`.

Full docs and the compose example are in the GitHub repository.
