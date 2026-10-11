# MangoWC Setup — Devuan Port

Port of [justaguylinux `mangowc-setup`](https://justaguy.dev/drew/mangowc-setup)
(Debian 13 trixie + systemd) for **Devuan Excalibur** (Debian 13 base,
**no systemd**). Upstream is kept as `upstream` git remote; this repo tracks
the Devuan-compatible `install.sh` plus the notes below.

> Tested target: Devuan 6 Excalibur, init `runit` (default) or `sysvinit`.
> Devuan Daedalus (Debian 12 base) is refused on purpose — same wlroots
> reason as upstream (see README "Why 0.14.4, and Why the Pin").

## What changed vs upstream

| Upstream (systemd) | This port |
|---|---|
| Refuses anything but Debian 13 | Accepts Devuan Excalibur (`/etc/devuan_version`, `ID=devuan`, `debian_version` 13.x) |
| `systemctl is-active display-manager` | Portable `dm_active()` (pgrep for lightdm/sddm/gdm/greetd/ly/…) |
| `systemctl enable avahi-daemon acpid` | `enable_service()` → `systemctl` on systemd, `/run/runit/service` symlink on runit, `update-rc.d` on sysvinit |
| `systemctl disable --now seatd` (always) | Conditional: seatd disabled only if (e)logind or a DM owns the seat; **enabled** for plain TTY start (required for DRM master without logind) |
| Installs nothing for seats (logind assumed) | Installs `elogind` + `seatd` on Devuan |
| `systemd-detect-virt` for VM cursor fix | `in_vm()` with `/proc/cpuinfo` + DMI fallback |
| lightdm installer assumed | Warns on Devuan, recommends `greetd + elogind` |

## Recommended Devuan setup (Asus X455LD / old Intel)

```bash
sudo apt-get install -y git
git clone https://github.com/razael25/mangowc-setup-devuan.git
cd mangowc-setup-devuan
chmod +x install.sh
./install.sh
```

Afterwards:

```bash
# seat/render groups (re-login after)
sudo usermod -aG video,input,render,seat "$USER"

# runit: enable what the installer may have missed
sudo ln -s /etc/sv/elogind /run/runit/service/     # if using a display manager
# or, for pure TTY start (no DM, no elogind):
sudo ln -s /etc/sv/seatd /run/runit/service/

# display manager (pick ONE):
sudo apt-get install -y greetd elogind   # recommended, systemd-free
# /etc/greetd/config.toml -> command = "mango-session"
```

Start from TTY without a DM:

```bash
seatd-run mango   # if seatd owns the seat
# or: mango       # if elogind is running
```

## Known limitations

- **NVIDIA proprietary + scenefx is untested upstream** and stays untested
  here. On Optimus laptops (e.g. GT 820M) use Intel modesetting first.
- `mpd-mpris` hint in upstream README uses
  `systemctl --user enable --now`; on Devuan run it via the user service
  manager you use (or autostart it from `config.conf` `exec-once`).
- `power-profiles-daemon` ships a systemd unit upstream; on runit it runs
  as a plain daemon — start it from `config.conf` or a runit user service.
- butterrepo `.deb`s are built for trixie; they install cleanly on
  Excalibur (same library versions), but re-run `./install.sh` after every
  `git pull` so new pins are picked up.
