#!/usr/bin/env bash
# Boot the ISO headless in QEMU/KVM (UEFI + Secure Boot with Microsoft keys, like a real laptop),
# save screenshots to out/boot-test/, and run checks inside the guest via qemu-guest-agent.
# Usage: tools/boot-test.sh [uefi|bios]
set -euo pipefail
cd "$(dirname "$0")/.."
ISO="$(ls -1 out/*.iso | head -1)"
OUT=out/boot-test; mkdir -p "$OUT"
T=/var/tmp/cisa-boot-test; mkdir -p "$T"
MON="$T/monitor.sock"; QGA="$T/qga.sock"; rm -f "$MON" "$QGA"
mode=${1:-uefi}

FW=()
if [[ $mode != bios ]]; then
  cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd "$T/vars.fd"
  FW=(-machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on
      -drive if=pflash,format=raw,unit=0,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.secboot.fd
      -drive if=pflash,format=raw,unit=1,file="$T/vars.fd")
fi

qemu-system-x86_64 -enable-kvm -cpu host -smp 2 -m 4096 "${FW[@]}" \
  -cdrom "$ISO" -boot d -vga virtio -display none \
  -monitor unix:"$MON",server,nowait -serial file:"$T/serial.log" \
  -chardev socket,path="$QGA",server=on,wait=off,id=qga0 \
  -device virtio-serial -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 &
QPID=$!
trap 'kill $QPID 2>/dev/null || true' EXIT

shot() {  # shot <seconds> <name>
  sleep "$1"
  echo "screendump $T/$2.ppm" | socat - UNIX-CONNECT:"$MON" >/dev/null
  sleep 1; convert "$T/$2.ppm" "$OUT/$2.png" && echo "saved $OUT/$2.png"
}

qga() {  # qga <json> -> the agent's reply to that command (after a sync handshake)
  local id=$RANDOM
  { printf '{"execute":"guest-sync","arguments":{"id":%d}}\n%s\n' "$id" "$1"; sleep 3; } \
    | socat -t8 - UNIX-CONNECT:"$QGA" | grep -vE "\"return\": ?$id\}" | tail -1 || true
}

guest() {  # guest <shell command>  -> prints stdout of the command run as root in the VM
  local reply pid out
  reply=$(qga "$(jq -cn --arg c "$1" '{execute:"guest-exec",arguments:{path:"/bin/sh",arg:["-c",$c],"capture-output":true}}')")
  pid=$(echo "$reply" | jq -r '.return.pid // empty' 2>/dev/null)
  if [[ -z $pid ]]; then echo "(guest agent: no pid; raw reply: ${reply:-<empty>})"; return 0; fi
  sleep 2
  out=$(qga "{\"execute\":\"guest-exec-status\",\"arguments\":{\"pid\":$pid}}")
  echo "$out" | jq -r '.return["out-data"] // empty' | base64 -d
  echo "$out" | jq -r '.return["err-data"] // empty' | base64 -d >&2
}

if [[ ${QUICK:-} == 1 ]]; then
  sleep 100
else
  shot 6   "$mode-1-bootmenu"
  shot 40  "$mode-2-booting"
  shot 60  "$mode-3-desktop"
  shot 30  "$mode-4-desktop-later"
fi

echo "== in-guest checks"
qga '{"execute":"guest-ping"}'; echo
guest 'cat /etc/issue; uname -r; mokutil --sb-state 2>/dev/null || dmesg | grep -i "secure boot" | head -2'
guest 'id cisa'
guest 'ps -eo comm | grep -E "plasmashell|kwin|firefox|plasma-welcome|calamares" | sort | uniq -c'
guest 'f=/home/cisa/.config/plasma-org.kde.plasma.desktop-appletsrc; grep -E "^\[|launchers|^icon=|plugin=" "$f"'
guest 'ls /home/cisa/Desktop'
guest 'export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin; ls /usr/share/applications/cisa-*.desktop | wc -l; for t in nmap msfconsole burpsuite ghidra wireshark sqlmap hashcat; do command -v $t >/dev/null && echo "OK $t" || echo "MISSING $t"; done'
guest 'ls /usr/lib/firefox-esr/distribution/'
echo "== serial log tail"; tail -3 "$T/serial.log" 2>/dev/null || true
