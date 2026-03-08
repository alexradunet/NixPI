# Xvfb + Xpra Display Stack — Design

**Date:** 2026-03-08
**Status:** Approved
**Replaces:** Sway + wayvnc Wayland stack

## Motivation

Bloom's display stack currently serves a human desktop (Sway + wayvnc). Pi runs in a terminal and has no GUI capabilities. This redesign gives Pi full computer use — web browsing, desktop app control, and general-purpose GUI autonomy — while letting the human observe and take over via Xpra.

## Decision Summary

| Choice | Decision |
|---|---|
| Display server | Xvfb (X Virtual Framebuffer) — software rendering, no GPU needed |
| Window manager | i3 (tiling, IPC-scriptable, deterministic layout) |
| Remote access | Xpra (session persistence, HTML5 client on :14500) |
| Terminal | alacritty (X11-native) |
| Agent interaction | Vision (screenshots) + AT-SPI2 (accessibility tree) |
| Pi integration | `bloom-display` extension with combined `display(action)` tool |
| Orchestration | Xpra-managed — single process owns Xvfb + i3 lifecycle |
| Physical monitor | Xpra client via greetd initial_session |
| Security | NetBird mesh boundary (no Xpra auth layer) |
| GPU acceleration | Not needed — software rendering is sufficient for target hardware |
| Rollout | Full replacement of Sway/wayvnc in one pass |

## Architecture

```
bloom-display.service (systemd, starts on graphical.target)
  |
  +-- xpra start :99
        |
        +-- Xvfb :99            (virtual X11 display, framebuffer in RAM)
        |     |
        |     +-- i3             (tiling WM, manages windows)
        |           |
        |           +-- alacritty (terminal running Pi)
        |           +-- chromium  (when Pi launches it)
        |           +-- (any app)
        |
        +-- Xpra server          (watches Xvfb, encodes frames)
        |     |
        |     +-- HTML5 :14500   (human connects via browser over NetBird)
        |     +-- xpra attach    (native client or greetd physical monitor)
        |
        +-- Session persistence  (clients disconnect/reconnect, apps keep running)
```

Pi's tools talk directly to `DISPLAY=:99`:
- `xdotool` — mouse/keyboard injection (X11 events)
- `scrot` — screenshots (reads X11 framebuffer)
- AT-SPI2 — accessibility tree (D-Bus, same session)
- `i3-msg` — window/workspace management (i3 IPC)

Xpra is purely the human's transport layer. Pi never goes through Xpra.

## Boot Sequence

```
boot
  |
  +-- bloom-display.service starts (graphical.target)
  |     +-- xpra start :99 --start=i3 -> i3 autostart -> alacritty -> Pi
  |
  +-- greetd.service starts (tty1)
        +-- initial_session: xpra attach :99
              +-- physical monitor shows the live session
```

Headless case: greetd's initial_session runs but has no output device. bloom-display.service keeps running. HTML5 client at :14500 is always available.

## OS Image Changes

### Packages Removed

`sway`, `wayvnc`, `xdg-desktop-portal-wlr`, `wl-clipboard`, `grim`, `slurp`, `foot`

### Packages Added

`xpra`, `xorg-x11-server-Xvfb`, `i3`, `xdotool`, `scrot`, `at-spi2-core`, `python3-pyatspi`, `alacritty`

### Files Removed

- `os/sysconfig/sway-config`

### Files Added

- `os/sysconfig/bloom-display.service` — systemd unit
- `os/sysconfig/i3-config` — agent-optimized i3 config
- `os/scripts/ui-tree.py` — AT-SPI2 JSON walker
- `extensions/bloom-display.ts` — combined `display(action)` tool
- `tests/bloom-display.test.ts` — extension tests

### Files Modified

- `os/Containerfile` — swap packages, configs, enable bloom-display.service
- `os/sysconfig/greetd.toml` — initial_session: `xpra attach :99`
- `os/sysconfig/bloom-bashrc` — add `export DISPLAY=:99`
- `README.md`, `AGENTS.md` — update display stack references

## bloom-display.service

```ini
[Unit]
Description=Bloom Display (Xpra + Xvfb + i3)
After=network.target

[Service]
User=bloom
Environment=DISPLAY=:99
ExecStart=xpra start :99 \
    --start=i3 \
    --bind-tcp=0.0.0.0:14500 \
    --html=on \
    --no-daemon
ExecStop=xpra stop :99
Restart=on-failure

[Install]
WantedBy=graphical.target
```

## i3 Configuration

Baked into the image at `/etc/xdg/i3/config`:

```
set $mod Mod4
workspace_layout tabbed
default_border pixel 1

workspace 1 output *
workspace 2 output *

exec --no-startup-id alacritty -T "Bloom Pi" -e bash --login
```

Tabbed layout: Pi drives one app at a time. Screenshots always show a single full-screen app. Pi switches workspaces via `i3-msg`.

## bloom-display Extension

Combined tool: `display(action, ...params)`

| Action | Params | Returns | Underlying |
|---|---|---|---|
| `screenshot` | `region?` (x,y,w,h) | Base64 PNG | `scrot` |
| `click` | `x, y, button?` | Confirmation | `xdotool mousemove --sync click` |
| `type` | `text` | Confirmation | `xdotool type --delay 50` |
| `key` | `keys` (e.g. "ctrl+l") | Confirmation | `xdotool key` |
| `move` | `x, y` | Confirmation | `xdotool mousemove --sync` |
| `scroll` | `x, y, direction, clicks?` | Confirmation | `xdotool click 4/5` |
| `ui_tree` | `app?` | JSON tree | AT-SPI2 via `ui-tree.py` |
| `windows` | — | JSON window list | `i3-msg -t get_tree` |
| `workspace` | `number` | Confirmation | `i3-msg workspace` |
| `launch` | `command` | PID | `DISPLAY=:99 command &` |
| `focus` | `window_id` or `title` | Confirmation | `i3-msg '[...] focus'` |

Environment: all subprocesses inherit `DISPLAY=:99`.

Error handling: if bloom-display.service isn't running, tools return "Display service not running."

## greetd Configuration

```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --remember-session --cmd 'xpra attach :99'"
user = "greetd"

[initial_session]
command = "xpra attach :99"
user = "bloom"
```

## Security

- Xpra HTML5 on `0.0.0.0:14500` — reachable only via NetBird mesh peers
- No Xpra authentication — NetBird mesh is the security boundary
- `DISPLAY=:99` scoped to `bloom` user via Unix socket permissions
- AT-SPI2 on session D-Bus, scoped to `bloom` user
- Replaces port 5901 (wayvnc) with 14500 (Xpra). Net: swap one port.

## Port Summary

| Port | Service | Access |
|---|---|---|
| 14500 | Xpra HTML5 | NetBird mesh |
| 5901 | ~~wayvnc~~ (removed) | — |
