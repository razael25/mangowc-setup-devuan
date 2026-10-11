# Panduan Install Offline: Fedora + Devuan Dual-Boot + rEFInd + MangoWC

Dokumen tunggal untuk instalasi tanpa akses AI. Mesin: **Asus X455LD**,
UEFI + GPT, layar laptop **tetap terpasang**, HDMI sebagai monitor kedua.
Ditulis untuk repo `mangowc-setup-devuan` (port Devuan dari
justaguylinux `mangowc-setup`).

---

## 0. Data awal mesin (hasil inspeksi, 11 Okt 2026)

```
sda  238,5G
├─sda1  600M vfat  /boot/efi   (ESP bersama)
├─sda2    2G ext4  /boot       (Fedora)
└─sda3  235,9G btrfs /         (Fedora 44, sway, sisa ~222G)
sdb  698,6G ntfs               (data "New Volume")
Boot: EFI/fedora/shimx64.efi  (Secure Boot kemungkinan AKTIF)
```

Keputusan yang sudah diambil dan jangan diubah di tengah jalan:

| # | Keputusan |
|---|---|
| 1 | Devuan di `sdb` (shrink NTFS → ±50G ext4 untuk `/`). `sda`/Fedora tidak disentuh.
Catatan: `sdb` adalah **HDD Hitachi 750GB 5400rpm** (bukan SSD), jadi Devuan
boot + buka aplikasi lebih lambat daripada Fedora di SSD. Ini harga dari opsi
aman. Alternatif cepat (berisiko): shrink `sda3` btrfs dan taruh `/` Devuan
±40G di SSD — hanya bila kamu nyaman resize btrfs dari Fedora live |

> Jika suatu saat Devuan terasa lambat di HDD dan kamu ingin pindah ke SSD,
> caranya: clone partisi `/` ke ruang baru di `sda`, update UUID di
> `/etc/fstab` Devuan + entry rEFInd, lalu `efibootmgr` ulang. Jangan
> menghapus partisi lama sebelum yang baru terbukti boot.
| 2 | Devuan **Excalibur** netinstall **+ firmware non-free**, init **runit**, tasksel hanya *Standard system utilities* |
| 3 | Bootloader utama **rEFInd** (auto-scan kernel). GRUB Fedora + GRUB Devuan disimpan sebagai fallback |
| 4 | MangoWC dari repo ini (port Devuan), BUKAN script upstream mentah (butuh systemd) |
| 5 | GPU: Intel HD 4400 modesetting dulu. NVIDIA GT 820M proprietary **jangan** dipakai dulu (scenefx belum teruji) |

---

## 1. Persiapan (di Fedora, masih online)

```bash
# 1a. Backup info boot + fstab (simpan ke USB / HP)
efibootmgr -v > ~/boot-backup.txt
lsblk -f >> ~/boot-backup.txt
cat /etc/fstab >> ~/boot-backup.txt
cp ~/boot-backup.txt /run/media/$USER/<USB>/

# 1b. Backup /home (cukup data penting, sistem 13G)
# 1c. Siapkan 2 USB: (A) Devuan Excalibur netinstall + non-free firmware,
#     (B) Fedora live (untuk rescue kalau boot rusak)
#     Tulis dengan dd / Fedora Media Writer, colok dan test boot UEFI
```

## 2. BIOS (sekali saja)

Masuk BIOS (`F2` saat power, tampil di layar internal):

- `Secure Boot` → **Disabled** (wajib: Devuan + rEFInd tidak signed shim Fedora)
- `Fast Boot` → **Disabled** (supaya HDMI sempat init)
- Cari opsi CSM bila ada → **Enabled**
- Simpan, matikan.

## 3. Bebaskan ruang di sdb (dari Fedora live / GParted)

1. Boot Fedora live, buka GParted → pilih `sdb`.
2. Shrink partisi NTFS dari **belakang**, sisakan **unallocated ±50G** (minimum 30G).
3. Jangan buat partisi dulu dari sini — biarkan unallocated, installer Devuan yang buat.
4. Reboot ke USB Devuan.

## 4. Install Devuan (manual partitioning — BACA PELAN)

1. Boot USB Devuan (UEFI mode). Pilih **Install**, hostname, user, password.
2. Saat partisi pilih **Manual**:
   - Klik ruang unallocated di `sdb` → buat partisi **ext4, mount `/`**, ±50G (atau seluruh unallocated).
   - **JANGAN** buat swap (Fedora pakai zram, Devuan ikut oke tanpa swap file).
   - Klik `sda1` (ESP 600M) → *Use as: EFI System Partition*, mount **`/boot/efi`**,
     pilihan **Format → TIDAK / NO**. Ini titik paling berbahaya: kalau ke-format,
     Fedora ikut hilang.
3. Init: bila ditanya, pilih **runit** (fallback aman: sysvinit).
4. Tasksel (pemilihan software): **hilangkan semua centang** kecuali
   `Standard system utilities`. Tanpa desktop environment.
5. Install GRUB: **Yes**, device = `sda1` (ESP yang sama, folder `EFI/debian`,
   tidak menimpa folder `EFI/fedora`).
6. Selesaikan install, cabut USB, reboot. Akan muncul GRUB Devuan dulu — normal.

## 5. rEFInd sebagai bootloader utama (dari Fedora)

```bash
# 5a. Boot ke Fedora (pilih via GRUB Devuan → Fedora, atau F12 → Fedora)
sudo dnf install -y refind
sudo refind-install
# 5b. Pastikan driver ada:
ls /boot/efi/EFI/refind/drivers_x64/ | grep -E "ext4|btrfs"
# 5c. Jadikan rEFInd boot pertama (ganti XXXX dengan nomor rEFInd):
efibootmgr -v
sudo efibootmgr -o XXXX,0000
# 5d. Rapikan duplikat (opsional): di /boot/efi/EFI/refind/refind.conf
#     dont_scan_files shimx64.efi,mmx64.efi
#     timeout 5
```

Mulai sekarang tiap boot tampil menu rEFInd: kernel Fedora + kernel Devuan
terdeteksi otomatis (tidak perlu edit config tiap update kernel).
GRUB keduanya tetap ada untuk darurat (F12 → `Fedora` / `debian`).

## 6. Post-install Devuan (wajib sebelum MangoWC)

```bash
# 6a. Grup hardware (lalu LOGOUT + LOGIN ulang)
sudo usermod -aG video,input,render,seat "$USER"

# 6b. Seat manager (runit) — pilih SALAH SATU sesuai cara login:
#   Pakai display manager (disarankan) → elogind:
sudo apt-get install -y elogind greetd
sudo ln -s /etc/sv/elogind /run/runit/service/
sudo ln -s /etc/sv/greetd /run/runit/service/
#   (greetd config /etc/greetd/config.toml → command = "mango-session")
#   TANPA display manager (start dari TTY) → seatd:
# sudo apt-get install -y seatd
# sudo ln -s /etc/sv/seatd /run/runit/service/
# Aturan: JANGAN jalankan seatd + elogind/DM bersamaan (rebutan DRM master,
# sesi blank 8 detik lalu greeter hang).

# 6c. Samakan jam (hindari jam loncat antar OS):
sudo apt-get install -y ntpsec  # atau pakai chrony; pastikan UTC di kedua OS
```

## 7. Install MangoWC (port Devuan, repo ini)

```bash
sudo apt-get install -y git
git clone https://github.com/razael25/mangowc-setup-devuan.git
cd mangowc-setup-devuan
chmod +x install.sh
./install.sh
# Ikuti prompt. Catat bagian NetworkManager: bila installer memperingatkan
# interface "unmanaged", serahkan ke NetworkManager (perintah ada di output).
```

Setelah selesai: reboot (bila tadi belum ada DM) atau logout total (grup
`render` baru aktif saat login baru) → pilih **Mango** di layar login.

- Keybinding: `Super+Return` terminal, `Super+Space` launcher,
  `Super+/` cheatsheet, `Super+Shift+P` wallpaper, `Super+Shift+M` command menu.
- Monitor kedua (HDMI): command menu → **Displays** (drag susunan, trial
  15 detik — jangan panik kalau layar hitam sesaat).
- Update setup: `cd mangowc-setup-devuan && git pull && ./install.sh`
  (backup `~/.config/mango` → jawab yes).

## 8. Perawatan dual-boot (jadwal)

- Update harian Devuan: `sudo apt update && sudo apt upgrade` (kecil, jarang reboot).
- Update Fedora: `sudo dnf upgrade` (kernel baru otomatis muncul di rEFInd).
- Update kernel Devuan: otomatis muncul di rEFInd juga. (Bila boot via GRUB
  Fedora langsung, jalankan `sudo grub2-mkconfig -o /boot/grub2/grub.cfg`
  dari Fedora.)
- Upgrade major Devuan (±2 tahun): baca release notes, backup, `dist-upgrade`,
  lalu rebuild/refresh MangoWC (wlroots ganti soname).
- Jangan campur repo `stable + testing + ceres`.

## 9. Troubleshooting (tanpa internet)

| Gejala | Penyebab umum | Perbaikan |
|---|---|---|
| `no bootable device` / langsung BIOS | BootOrder ke-reset | F12 → pilih Fedora/debian; dari OS: `efibootmgr -o` kembalikan rEFInd pertama |
| rEFInd hilang setelah update Fedora | `shim` tulis ulang BootOrder | `sudo refind-install` ulang dari Fedora |
| Mango blank 8 detik lalu greeter hang | seatd + elogind/DM rebutan GPU | Matikan salah satu (lihat §6b) |
| Mango gagal buka render node | user belum grup `render` / belum login ulang | `groups`, pastikan ada `render`, relogin |
| Bar network offline padahal konek | interface di `/etc/network/interfaces` | Komentari baris `iface <dev>` itu, reboot (detail di output installer) |
| Kernel baru Devuan tidak muncul di GRUB Fedora | entry GRUB statis | Boot via rEFInd, atau `grub2-mkconfig` dari Fedora |
| Layar HDMI tidak tampil di BIOS | Fast Boot on / kabel longgar | Matikan Fast Boot (§2), colok HDMI sebelum power |

Darurat total: boot USB Fedora live → mount ESP → `efibootmgr -c`
buat entry manual, atau `chroot` + `grub2-install` / `update-grub`.

---

*Sumber: inspeksi Fedora 44 + X455LD (11 Okt 2026), README upstream,
`install.sh` port ini, dan `DEVUAN.md`. Kalau menemukan langkah yang
kadaluwarsa, perbaiki file ini via pull request.*
