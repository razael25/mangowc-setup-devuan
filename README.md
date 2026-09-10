# 🥭 mangowc-setup

![Made for Debian](https://img.shields.io/badge/Made%20for-Debian%2013-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![MangoWC](https://img.shields.io/badge/MangoWC-Wayland-5294E2?style=for-the-badge&logo=wayland&logoColor=white)
![Stars](https://img.shields.io/gitea/stars/drew/mangowc-setup?gitea_url=https://justaguy.dev&style=for-the-badge&logo=forgejo&logoColor=white&color=yellow&label=Stars)
![Forks](https://img.shields.io/gitea/forks/drew/mangowc-setup?gitea_url=https://justaguy.dev&style=for-the-badge&logo=forgejo&logoColor=white&color=blue&label=Forks)
![Last Commit](https://img.shields.io/gitea/last-commit/drew/mangowc-setup?gitea_url=https://justaguy.dev&style=for-the-badge&logo=forgejo&logoColor=white&color=green&label=Last%20Commit)

A MangoWC rice script for Debian 13 (trixie).
One script installs the compositor, the bar, and everything in between, drops
in the config, and you're tiling — with animations — on plain Debian stable.

> Part of the [JustAGuy Linux](https://justaguy.dev/drew) window manager collection — installable standalone or via [butterknife](https://justaguy.dev/drew/butterknife), the installer for [Butterbian](https://butterbian.org).

![MangoWC Desktop](screenshots/desktop.png)

---

## 🤔 What is MangoWC?

[Mango](https://github.com/mangowm/mango) is a Wayland compositor built on
dwl — dwm's model, brought to Wayland. Tags instead of workspaces. Master and
stack, with a dozen other layouts a keypress away. A flat `key=value` config
that reloads while you watch.

Then it adds the part dwm never had: window animations, blur, shadows and
rounded corners, courtesy of [scenefx](https://github.com/wlrfx/scenefx).
Think **dwm's brain with Hyprland's face**, in a few thousand lines of C, and
no Hyprland.

---

## 🚀 Installation

```bash
git clone https://justaguy.dev/drew/mangowc-setup.git
cd mangowc-setup
chmod +x install.sh
./install.sh
```

Then log out (all the way — a group membership changes) and pick **Mango**
at the login screen.

```
Options:
  --only-config      Only copy config files (skip packages)
  --help             Show help message
```

> ⚠️ **NVIDIA users:** Wayland on the proprietary driver needs kernel
> modesetting and a couple of environment variables. The installer runs
> `nvidia-setup.sh` when it detects one; it's also copied to
> `~/nvidia-setup.sh` so you can re-run it. Unlike sway, mango needs no
> `--unsupported-gpu` flag.

---

## 📦 What It Installs

trixie ships wlroots 0.18, and mango needs 0.19 plus scenefx. So the
compositor stack comes from [butterrepo](https://justaguy.dev/drew/butterrepo)
as proper `.deb`s, built in a clean trixie container by
[deb-builders](https://justaguy.dev/drew/deb-builders):

| Package (butterrepo)        | Purpose                                                        |
|-----------------------------|----------------------------------------------------------------|
| `mangowc`                   | The compositor — 0.14.4, built with 12 tags                    |
| `libwlroots-0.19`           | Its wlroots, side by side with Debian's 0.18 (sway keeps working) |
| `libscenefx-0.4`            | Blur, shadows, rounded corners                                 |
| `quickshell`                | The bar and every popup                                        |
| `rofi`                      | Launcher, power menu, keybind cheatsheet                       |
| `awww`                      | Wallpaper daemon (the artist formerly known as swww) — wallpapers wipe in, they don't just appear |

Everything else is stock Debian:

| Component                     | Purpose                              |
|-------------------------------|--------------------------------------|
| `dunst`                       | Notifications (layer-shell native)   |
| `grim` + `slurp`              | Screenshots                          |
| `cliphist` + `wl-clipboard`   | Clipboard history                    |
| `xdg-desktop-portal-wlr/gtk`  | Screen sharing, file dialogs         |
| `kitty`                       | Terminal (via butterscripts)         |
| `thunar` + plugins            | File manager                         |
| `pipewire`                    | Audio                                |
| `nwg-look`, `nwg-displays`    | GTK / display configurators          |
| `wlsunset`, `power-profiles-daemon`, `brightnessctl` | The command menu's toggles |

> 💡 _Themes by [vinceliuice](https://github.com/vinceliuice) — Orchis (GTK) and Colloid (icons)._

---

## 📊 The Bar

The same quickshell shell that runs the dwm, bspwm and openbox setups, with a
mango backend. Tags, occupancy, urgency, focused title and layout come from a
single `mmsg watch` stream — no polling, no patch — and clicks go back through
`mmsg dispatch`.

| Module      | Left click               | Right click             | Scroll         |
|-------------|--------------------------|-------------------------|----------------|
| Launcher    | rofi                     | wallpaper picker        | —              |
| Tags        | view                     | —                       | cycle tags     |
| Layout      | layout + tweaks picker   | (empty bar: same)       | cycle layouts  |
| Media       | play / pause             | now-playing popup       | prev / next    |
| Weather     | 3-day forecast           | location / units        | —              |
| Volume      | mute                     | pavucontrol             | ±2%            |
| Network     | network app (Wi-Fi, VPN, Bluetooth) | nm-connection-editor | —  |
| Clock       | calendar                 | —                       | —              |
| Screenshot  | region                   | full screen             | —              |
| Commands    | command menu             | —                       | —              |

The **layout picker** shows all fourteen mango layouts as glyph tiles, plus
live sliders for gaps, master width and master count, and the bar's own
height and scale. The **command menu** holds the toggles that don't earn a
bar module: power profile, keep-awake, night light, DND, a pomodoro.

Details in [`config/quickshell/README.md`](config/quickshell/README.md).

---

## 🎨 Wallpaper-Driven Theming

`Super + Shift + P` opens the wallpaper picker. Pick an image and the desktop
re-colors itself from it: the bar, rofi, dunst, kitty, the GTK theme and icon
set, and mango's own border colors — then the new wallpaper wipes across the
screen. The palette is extracted right in the picker; nothing to configure.
Wallpapers live in `~/.config/mango/wallpaper/`. Drop in your own and they
show up next time you open it.

---

## 🔑 Keybindings Overview

Super is the mod key. Same muscle memory as the other setups.

| Key Combo              | Action                                |
|------------------------|----------------------------------------|
| `Super + Return`       | Terminal (kitty)                       |
| `Super + Space`        | App launcher (rofi)                    |
| `Super + /`            | Keybind cheatsheet                     |
| `Super + Q`            | Close window                           |
| `Super + Shift + Q`    | Quit mango                             |
| `Super + Shift + R`    | Reload config (live)                   |
| `Super + X`            | Power menu                             |
| `Super + B` / `Super + Shift + B` | Firefox / Firefox private   |
| `Super + C` / `Super + F` / `Super + E` | Helium / Thunar / Geany |
| `Super + Shift + Space`| Toggle floating                        |
| `Super + Shift + F`    | Fullscreen                             |
| `Super + T` / `Super + W` | Cycle layouts / Monocle             |
| `Super + Tab`          | Overview of every window               |
| `Alt + Tab`            | Next window                            |
| `Super + H/J/K/L` or arrows | Focus window                      |
| `Super + Shift + H/J/K/L` or arrows | Swap window               |
| `Super + Ctrl + ←/→`   | Master width                           |
| `Super + Ctrl + ↑/↓`   | Master count                           |
| `Super + 1–9/0/-/=`    | View tag 1–12                          |
| `Super + Shift + 1–9/0/-/=` | Send window to tag 1–12           |
| `Super + Shift + P`    | Wallpaper picker                       |
| `Super + Shift + M`    | Command menu                           |
| `Super + Shift + N`    | Network app                            |
| `Super + Shift + L`    | Layout / tweaks picker                 |
| `Super + S` / `Super + Shift + S` | Screenshot full / region (to `~/Screenshots`) |

Every bind in `config.conf` has a comment above it — that's what
`Super + /` reads, so add a bind, add a comment, and the cheatsheet knows.
`~/QUICKSTART-mango.md` lands in your home folder for the first few days.

---

## 📂 Configuration Files

```
~/.config/mango/
├── config.conf           # everything: look, input, layouts, autostart, binds, rules
├── theme.conf            # border colors, written by the wallpaper picker (sourced)
├── scripts/
│   ├── bar               # quickshell helper: restart | log | ipc …
│   ├── mango-ipc         # mmsg wrapper that finds the socket
│   ├── wallpaper-theme   # the theming engine
│   ├── screenshot        # grim/slurp: full | region
│   ├── changevolume      # volume + notifications
│   ├── power / help / network / weather
├── quickshell/           # the bar (see its README)
├── quickshell-network/   # the network app (its own qs instance)
├── rofi/                 # config / keybinds / power .rasi (colors theme-managed)
├── dunst/                # dunstrc (theme-managed)
├── polybar/colors.ini    # the live palette the bar watches (name is historical)
└── wallpaper/
```

---

## 🔢 Why 12 Tags?

Upstream mango has nine, as a compile-time array. Every other setup in this
collection has twelve workspaces on `Super + 1–9, 0, -, =`, so the butterrepo
build carries a one-line patch for twelve. The bar reads the count from the
compositor, so it just follows.

---

## 📌 Why 0.14.4, and Why the Pin

Short version: **mango 0.14.4 is the newest mango that can exist on
Debian 13.** Here's the chain, because "just use the latest" is the first
question everyone asks.

**1. Mango rides on wlroots.** Every mango release pins a wlroots series
(and a matching scenefx). trixie ships wlroots **0.18**. Mango hasn't run
on 0.18 for a long time, so any mango at all means packaging a newer
wlroots ourselves.

**2. wlroots 0.19 is the last one that builds on trixie's libraries.**
It compiles cleanly against stock trixie: same wayland, same libdrm, same
xkbcommon. So butterrepo ships it as `libwlroots-0.19`, a separate package
with version-suffixed paths that installs *next to* Debian's 0.18 — sway
and everything else on 0.18 keeps working untouched.

**3. wlroots 0.20 does not.** We test-built it in a clean trixie
container. It needs four base libraries newer than Debian 13 has:

| wlroots 0.20 needs        | trixie ships |
|---------------------------|--------------|
| wayland-server 1.24       | 1.23.1       |
| wayland-protocols 1.47    | 1.44         |
| libdrm 2.4.129            | 2.4.124      |
| xkbcommon 1.8             | 1.7.0        |

And they're not header-only gaps: it calls a libdrm function trixie's
runtime library doesn't export, and needs protocol files trixie's
wayland-protocols doesn't carry. Shipping replacements would mean a
third-party repo swapping out `libdrm` and `libwayland` underneath Mesa
and Xorg on every user's machine. That's not a line we're willing to
cross for a window manager.

**4. So the stack is pinned where wlroots 0.19 ends:**

| Package           | Version | Why this one                                      |
|-------------------|---------|---------------------------------------------------|
| `libwlroots-0.19` | 0.19.3  | Last wlroots series that builds on trixie          |
| `libscenefx-0.4`  | 0.4.1   | The scenefx series for wlroots 0.19                |
| `mangowc`         | 0.14.4  | Last mango on wlroots 0.19 / scenefx 0.4; 0.15.0 moved to 0.20 |

**"But scenefx 0.5 is out."** It is, and it's the same wall one layer up.
scenefx tracks wlroots one to one — its build file requires wlroots 0.20
and refuses anything older — and mango pins the pair together: 0.14.x
asks for the scenefx 0.4 API by name, 0.15+ for 0.5. So these aren't
three separate version choices. There's one choice, wlroots 0.19, and the
other two follow from it.

0.14.4 is the bugfix end of its line — a known-good snapshot, frozen the
way everything on Debian stable is frozen. It won't get upstream's newer
features (HDR, window groups, the GNOME-style switcher, configurable tag
count) and it won't get upstream's newer fixes either. What it *will* do is
stay exactly the same under you, which for a setup script is the point.

**5. Newer mango arrives with forky.** Debian 14 already carries wlroots
0.20.2 and scenefx 0.5 in its archive, so on that base current mango is an
ordinary build. That'll be a new branch of this setup, not a silent bump:
mango renames dispatchers between releases, and a config that works on
0.14 needs edits for 0.16.

---

## 🩹 Two Things the Installer Fixes for You

- **GPU render node access.** scenefx opens `/dev/dri/renderD*` directly
  at startup and fails hard if it can't. logind usually grants the active
  session an ACL on it — usually. The installer adds you to the `render`
  group so it never depends on timing. (This is the log-out-all-the-way
  step.)
- **seatd vs logind.** If the `seatd` daemon is running beside a display
  manager, mango can't become DRM master, the session dies in eight
  seconds, and lightdm's greeter hangs with it. Nothing here needs seatd;
  the installer disables it and logind keeps the seat.

Both were found the hard way so you don't have to.

---

## Credits

This project is a *config* on top of other people's software. Mango is by
[DreamMaoMao](https://github.com/DreamMaoMao) and
[contributors](https://github.com/mangowm/mango), on
[wlroots](https://gitlab.freedesktop.org/wlroots/wlroots) and
[scenefx](https://github.com/wlrfx/scenefx) (wlrfx). Quickshell by
[outfoxxed](https://git.outfoxxed.me/quickshell/quickshell). awww by
[LGFae](https://codeberg.org/LGFae/awww). rofi-wayland by
[lbonn](https://github.com/lbonn/rofi). dunst by the
[dunst project](https://dunst-project.org). kitty by
[Kovid Goyal](https://sw.kovidgoyal.net/kitty/). GTK + icon themes by
[vinceliuice](https://github.com/vinceliuice) —
[Orchis](https://github.com/vinceliuice/Orchis-theme) and
[Colloid](https://github.com/vinceliuice/Colloid-icon-theme).

---

## License

GPL-2.0 - See [LICENSE](LICENSE) for details.

## Support

<a href="https://www.buymeacoffee.com/justaguylinux" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy me a coffee" /></a>

## Connect

- [YouTube](https://youtube.com/@justaguylinux) — tutorials and guides
- [Butterforge](https://justaguy.dev/drew) — source code and projects
- [The Butter Lab](https://lab.justaguylinux.com) — Discourse forum
- [The Churn](https://justaguylinux.chat) — community chat (Fluxer)
- [Wiki](https://justaguy.wiki) — documentation and guides
- [Mastodon](https://fosstodon.org/@justaguylinux) — @justaguylinux@fosstodon.org
- [Butterbian](https://butterbian.org) — a Debian-based distro

---

Made with butter by JustAGuyLinux
