#!/bin/bash
# NVIDIA GPU Setup for MangoWC

set -e

die() { echo "ERROR: $*" >&2; exit 1; }
msg() { echo ">> $*"; }

# Check not root
[ "$EUID" -eq 0 ] && die "Do not run as root"

# Detect NVIDIA GPU
msg "Checking for NVIDIA GPU..."
lspci | grep -qi nvidia || { msg "No NVIDIA GPU found. Exiting."; exit 0; }

# Check for proprietary driver
msg "Checking for proprietary drivers..."
lsmod | grep -q "^nvidia " || { msg "Using open drivers. No setup needed."; exit 0; }

msg "NVIDIA proprietary drivers detected. Configuration required."
echo
read -p "Continue? (y/n) " -n 1 -r
echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

# Check kernel parameter
msg "Checking kernel parameters..."
if ! grep -q "nvidia-drm.modeset=1" /proc/cmdline 2>/dev/null; then
	echo
	echo "Add 'nvidia-drm.modeset=1' to kernel boot parameters:"
	echo
	if [ -f /etc/default/grub ]; then
		echo "  sudo nano /etc/default/grub"
		echo "  # Add to GRUB_CMDLINE_LINUX_DEFAULT"
		echo '  GRUB_CMDLINE_LINUX_DEFAULT="quiet nvidia-drm.modeset=1"'
		echo "  sudo update-grub"
	else
		echo "  Edit your bootloader config"
	fi
	echo
	msg "Reboot required after setting parameter."
	exit 0
fi

# No desktop-entry change needed: unlike sway, mango has no --unsupported-gpu
# gate. Kernel modesetting (above) and the environment below are the whole job.

# Environment variables
echo
read -p "Set NVIDIA environment variables? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
	mkdir -p "$HOME/.config/environment.d"
	cat > "$HOME/.config/environment.d/nvidia.conf" << 'EOF'
GBM_BACKEND=nvidia-drm
__GLX_VENDOR_LIBRARY_NAME=nvidia
WLR_NO_HARDWARE_CURSORS=1
EOF
	msg "Environment variables set."
fi

echo
msg "Setup complete. Log out and select Mango from display manager."
