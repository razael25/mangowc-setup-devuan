# 🥭 mangowc-setup

![Made for Debian](https://img.shields.io/badge/Made%20for-Debian-A81D33?style=for-the-badge&logo=debian&logoColor=white)
![MangoWC](https://img.shields.io/badge/MangoWC-Wayland-5294E2?style=for-the-badge&logo=wayland&logoColor=white)

A MangoWC rice script for Debian 13 (trixie).
Installs the compositor and everything around it, drops in the config, and
you're ready to go: animated tiling with a quickshell bar.

> Part of the [JustAGuy Linux](https://justaguy.dev/drew) window manager collection.

## What is MangoWC?

[Mango](https://github.com/mangowm/mango) is a Wayland compositor built on
dwl (dwm for Wayland): tags instead of workspaces, master/stack layouts, a
flat `key=value` config that hot-reloads. On top of that it adds window
animations, blur, shadows and rounded corners via scenefx. Think dwm's
model with Hyprland's look, in a few thousand lines of C.

## Installation

```bash
git clone https://justaguy.dev/drew/mangowc-setup.git
cd mangowc-setup
chmod +x install.sh
./install.sh
```

Options: `--only-config` copies the config without touching packages.

> **NVIDIA users:** the installer runs `nvidia-setup.sh` when it detects a
> proprietary driver (kernel modesetting + environment). It's also copied to
> `~/nvidia-setup.sh` to re-run later.

## What it installs

The compositor stack comes from [butterrepo](https://justaguy.dev/drew/butterrepo),
because trixie ships wlroots 0.18 and mango 0.14 needs 0.19 plus scenefx:

| Package | Purpose |
|---|---|
| `mangowc` | The compositor (0.14.4, built with 12 tags) |
| `libwlroots-0.19`, `libscenefx-0.4` | Its rendering stack, side by side with Debian's wlroots 0.18 |
| `quickshell` | The bar and its popups |
| `rofi` | Launcher, power menu, keybinding help |

Everything else is plain Debian: `swaybg` (wallpaper), `dunst`
(notifications), `grim`+`slurp` (screenshots), `wl-clipboard`+`cliphist`,
`xdg-desktop-portal-wlr`, `thunar`, `pipewire`, `kitty` (via butterscripts).

## The bar

The same quickshell shell as the dwm, bspwm and openbox setups, with a
mango backend: one `mmsg watch` stream feeds tags, focus, title and layout;
clicks go through `mmsg dispatch`. Wallpaper-driven theming re-colours the
bar, rofi, dunst, kitty, GTK and mango's borders from the image you pick.
Details in [`config/quickshell/README.md`](config/quickshell/README.md).

## Why 12 tags?

Upstream mango has nine, as a compile-time array. The butterrepo build
carries a one-line patch for twelve so the tag keys match every other
setup in the collection (Super+1–9, 0, minus, equal).

## Two things the installer fixes that you'd otherwise hit

- **GPU render node access.** scenefx opens `/dev/dri/renderD*` directly
  at startup and fails hard if it can't. The installer adds you to the
  `render` group so that never depends on logind's ACL timing.
- **seatd vs logind.** If the `seatd` daemon is running next to a display
  manager, mango can't become DRM master and the session dies, taking
  lightdm's greeter with it. The installer disables seatd; logind owns the
  seat.

## Keybindings

`Super + /` shows them all. See [QUICKSTART.md](QUICKSTART.md).
