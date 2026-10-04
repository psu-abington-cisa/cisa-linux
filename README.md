# CISA Linux

A beginner-friendly, Windows-familiar security distro for the
**Cybersecurity & IT Student Association (CISA) at Penn State Abington** —
*"Learn to hack. The legal way."*

- **Base:** Debian 13 "trixie" (stable). Metasploit, Burp Suite, Ghidra and CyberChef come from their
  vendors' own releases, so apt never mixes in another distro's packages
- **Desktop:** KDE Plasma laid out like Windows (bottom taskbar, Start menu, system tray)
- **Installer:** Calamares (graphical, click-through)
- **Tools:** curated beginner set matching Come Hack sessions, grouped in a "CISA Tools" menu

After installing, students can add a fully riced **Hyprland** desktop with nine themes (picked on the
login screen next to Plasma, which changes to match) using
[CISA Rice](https://github.com/psu-abington-cisa/cisa-rice):

```bash
curl -fsSL https://raw.githubusercontent.com/psu-abington-cisa/cisa-rice/main/install.sh | bash
```

## Building (from Windows, using WSL)

Requirements: WSL2 with a Debian-based distro (Kali works), ~30 GB free, internet.

```powershell
# from this folder in PowerShell
wsl -d kali-linux -u root -- bash ./build.sh
```

The ISO lands in `out/cisa-linux-<version>-amd64.iso`. Test it in VirtualBox/Hyper-V/VMware
(give the VM 4 GB RAM, 2 CPUs, EFI or BIOS both work), or write it to a USB with Rufus / balenaEtcher.

The live session logs in automatically as user `cisa` (sudo password: `live`, the live-config default).
The installer asks each student to create their own account.

## Checking a build (all run inside WSL as root)

| Script | What it does |
|---|---|
| `tools/check-packages.sh` | Confirms every name in `config/package-lists/` exists in Debian 13. Run it after editing the lists |
| `tools/lint.sh` | Syntax-checks all scripts and catches Windows line endings |
| `tools/verify-build.sh` | Inspects the finished image: vendor tools, installer package pool, branding, boot menu |
| `tools/boot-test.sh [uefi\|bios]` | Boots the ISO in QEMU/KVM (UEFI test uses Secure Boot with Microsoft keys), saves screenshots to `out/boot-test/`, and runs checks inside the VM |

## Layout

| Path | What it is |
|---|---|
| `build.sh` | Entry point: installs build deps, runs `live-build` |
| `auto/config` | live-build settings (distribution, archive areas, boot options) |
| `config/package-lists/` | What gets installed (desktop, tools, drivers) |
| `config/archives/` | Extra apt repos (Kali, pinned low so Debian wins) |
| `config/hooks/live/` | Scripts run inside the image during build (themes, tool installs) |
| `config/includes.chroot/` | Files copied verbatim into the OS (`/etc/skel` defaults, menus, wallpapers) |
| `config/bootloaders/` | Branded GRUB/ISOLINUX boot menu |
| `branding/` | Logo source + generated wallpaper / icons |

## Changing things

- **Add/remove a tool:** edit `config/package-lists/tools.list.chroot` (Debian/Kali package names).
  If it's only in Kali, also add it to `config/archives/kali.pref.chroot`.
- **Change the look:** `config/includes.chroot/etc/skel/.config/` holds the default Plasma layout.
- **Change branding:** replace `branding/source/cisa-logo.jpg` and rerun `build.sh`.
