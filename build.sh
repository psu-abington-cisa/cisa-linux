#!/usr/bin/env bash
# Build the CISA Linux ISO. Run as root inside WSL2 (or any Debian-based Linux).
set -euo pipefail
trap 'echo "BUILD FAILED at line $LINENO: $BASH_COMMAND" >&2' ERR

VERSION="${VERSION:-2026.10}"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
# Building on /mnt/c (NTFS) breaks permissions/devices, so work in the Linux filesystem.
WORK_DIR="${WORK_DIR:-/var/tmp/cisa-linux-build}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: wsl -d kali-linux -u root -- bash ./build.sh" >&2
  exit 1
fi

echo "==> Installing build dependencies"
# Don't let an unrelated broken third-party repo on the build host stop the build
apt-get update || echo "WARNING: some host apt sources failed to update; continuing" >&2
apt-get install -y live-build debootstrap xorriso squashfs-tools \
  grub-efi-amd64-bin grub-pc-bin mtools dosfstools isolinux syslinux-common \
  imagemagick curl ca-certificates

# Debian's debootstrap script for trixie must exist on the build host
if [[ ! -e /usr/share/debootstrap/scripts/trixie ]]; then
  ln -s sid /usr/share/debootstrap/scripts/trixie
fi

echo "==> Generating branding assets"
bash "$SRC_DIR/branding/make-branding.sh"

echo "==> Preparing work dir $WORK_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"
cp -a "$SRC_DIR/auto" "$SRC_DIR/config" "$WORK_DIR/"
chmod +x "$WORK_DIR"/auto/* "$WORK_DIR"/config/hooks/live/*.hook.chroot

echo "==> Branding the ISO boot menu"
# live-build renders its own splash and hard-codes "Live system" labels late in the
# binary stage, so overwrite both in a binary hook (runs right after that, before the ISO is made).
mkdir -p "$WORK_DIR/config/cisa-boot"
cp "$SRC_DIR"/branding/generated/boot/*.png "$WORK_DIR/config/cisa-boot/"
cat > "$WORK_DIR/config/hooks/live/9000-boot-branding.hook.binary" <<EOF
#!/bin/sh
set -e
B="$WORK_DIR/binary"
[ -d "\$B/boot/grub" ] && cp "$WORK_DIR/config/cisa-boot/grub-splash.png" "\$B/boot/grub/splash.png"
[ -d "\$B/isolinux" ] && cp "$WORK_DIR/config/cisa-boot/isolinux-splash.png" "\$B/isolinux/splash.png"
for f in "\$B"/boot/grub/*.cfg "\$B"/isolinux/*.cfg; do
  [ -f "\$f" ] && sed -i 's/Live system/CISA Linux Live/g' "\$f"
done
# Auto-boot after 10 s (live-build waits forever) and drop the startup beep
if [ -f "\$B/boot/grub/config.cfg" ]; then
  sed -i -e '/^insmod play/d' -e '/^play /d' "\$B/boot/grub/config.cfg"
  sed -i 's/^set default=0/set default=0\nset timeout=10/' "\$B/boot/grub/config.cfg"
fi
[ -f "\$B/isolinux/isolinux.cfg" ] && sed -i 's/^timeout 0/timeout 100/' "\$B/isolinux/isolinux.cfg"
exit 0
EOF
chmod +x "$WORK_DIR/config/hooks/live/9000-boot-branding.hook.binary"

cd "$WORK_DIR"
export CISA_VERSION="$VERSION"
lb clean --purge || true
lb config
lb build 2>&1 | tee build.log

ISO="$(ls -1 "$WORK_DIR"/*.iso | head -1)"
mkdir -p "$SRC_DIR/out"
cp "$ISO" "$SRC_DIR/out/cisa-linux-$VERSION-amd64.iso"
( cd "$SRC_DIR/out" && sha256sum "cisa-linux-$VERSION-amd64.iso" > "cisa-linux-$VERSION-amd64.iso.sha256" )
echo "==> Done: $SRC_DIR/out/cisa-linux-$VERSION-amd64.iso"
