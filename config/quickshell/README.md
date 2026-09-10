# quickshell shell for mango

The same desktop shell as the dwm / bspwm / openbox setups — bar, popups,
wallpaper-driven theming, and the network app — with a mango backend.
Nothing here touches X11: mango is a Wayland compositor and the bar is a
wlr-layer-shell panel.

Launch: `qs -p ~/.config/mango/quickshell -d -n` (config.conf's exec-once
does this), or `scripts/bar restart|log` which handles the `-p` flag.

## WM-specific files (everything else is shared verbatim with the other ports)

- `Wm.qml` — mango backend. One `mmsg watch all-monitors` stream (JSON,
  one line per state change, snapshot on connect) supplies tags,
  occupancy, urgency, focused title and layout. Actions go through
  `mmsg dispatch`. `scripts/mango-ipc` wraps mmsg and finds the socket
  when MANGO_INSTANCE_SIGNATURE is missing from the environment.
- `Bar.qml` — no Follow module (mango has no window-follow toggle).
- `LayoutPicker.qml` — the fourteen mango layouts as glyph tiles
  (`setlayout,<name>`); inner gap via `setoption,gappih/gappiv`
  (persisted to `mango-gaps`, re-applied by Wm.qml on start and after a
  config reload resets it); master width / count via the relative
  `setmfact` / `incnmaster` dispatches, tracked in Wm.qml since mango
  exposes no getter. Table in Wm.qml mirrors `src/layout/layout.h`.
- `Sys.qml` — caps lock read from `/sys/class/leds/*capslock`, popups
  always card-only (`composited: false`).
- `Commands.qml` — keep-awake is a `systemd-inhibit --what=idle` holder
  process; night light is wlsunset; the updates terminal is kitty.
- `Screenshot.qml` — `scripts/screenshot` (grim + slurp, clipboard).
- Tail of `scripts/wallpaper-theme` — mango: writes `theme.conf`
  (focus/border/urgent/root colours, sourced by config.conf) and
  `reload_config`; swaybg replaces the wallpaper and the config.conf
  exec-once line is rewritten.

Notifications are dunst (Wayland-native via layer-shell), so the
NotifyPopup / Bell / DND code is byte-identical to the X11 ports.

## Known gaps

- Popups are card-only xdg-popups: click-outside close is not available,
  Escape and the module's own button close them.
- Single-monitor state: Wm.qml follows the focused output.
