#!/usr/bin/env bash
# Inspect a finished build: hook warnings, key files/packages present in the image.
W="${WORK_DIR:-/var/tmp/cisa-linux-build}"
C="$W/chroot"
cd "$(dirname "$0")/.."

echo "== ISO"; ls -lh out/*.iso
echo "== Vendor tool warnings"; cat "$C/var/log/cisa-vendor-tools.log" 2>/dev/null || echo "(none)"
echo "== Hook/apt errors in build.log"
grep -nE '^E: |WARNING:|BUILD FAILED|hook.*(failed|error)|No such file' "$W/build.log" | grep -v 'cisa-vendor' | head -30
echo "== Vendor tools present"
for p in /opt/ghidra/ghidraRun /opt/cyberchef/index.html /opt/BurpSuiteCommunity/BurpSuiteCommunity /opt/metasploit-framework/bin/msfconsole; do
  chroot "$C" test -e "$p" && echo "OK   $p" || echo "MISS $p"   # inside chroot: links are absolute
done
echo "== Installer package pool on ISO"
for p in grub-efi-amd64 grub-efi-amd64-signed shim-signed grub-pc cryptsetup-initramfs; do
  ls "$W"/binary/pool/*/*/*/"${p}"_*.deb >/dev/null 2>&1 && echo "OK   $p" || echo "MISS $p"
done
echo "== Key packages"
for p in kde-plasma-desktop sddm calamares calamares-settings-debian firefox-esr nmap wireshark burpsuite metasploit-framework sqlmap hashcat autopsy default-jdk; do
  chroot "$C" dpkg-query -W -f='${Status} ${Package}\n' "$p" 2>/dev/null | grep -q '^install ok installed' && echo "OK   $p" || echo "--   $p"
done
echo "== CISA launchers"; ls "$C"/usr/share/applications/cisa-*.desktop | wc -l
echo "== Calamares branding"; grep -H '^branding' "$C/etc/calamares/settings.conf"; ls "$C/etc/calamares/branding/cisa/"
echo "== Boot menu"; grep -h 'CISA Linux Live' "$W"/binary/boot/grub/grub.cfg "$W"/binary/isolinux/*.cfg 2>/dev/null | head -4
identify "$W/binary/boot/grub/splash.png" "$W/binary/isolinux/splash.png" 2>/dev/null
echo "== Top space users in image (MB)"
du -sm "$C"/opt/* "$C"/usr/share/* "$C"/usr/lib/* 2>/dev/null | sort -rn | head -12
