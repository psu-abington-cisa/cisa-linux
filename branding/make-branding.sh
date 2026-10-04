#!/usr/bin/env bash
# Generate all branding images from branding/source/cisa-logo.jpg.
# Palette comes from cisa.cybernet.rocks: navy #0b1f3a, ink #0f1b2d, accent #1d5fd6, paper #f7f6f2.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/branding/source/cisa-logo.jpg"
GEN="$ROOT/branding/generated"
INC="$ROOT/config/includes.chroot"
NAVY="#0b1f3a"; INK="#0f1b2d"; ACCENT="#1d5fd6"; PAPER="#f7f6f2"
TAGLINE="Learn to hack. The legal way."

IM=convert; command -v magick >/dev/null && IM=magick
FONT="$(fc-match -f '%{file}' 'DejaVu Sans:bold' 2>/dev/null || true)"
FONT_ARG=(); [[ -n $FONT ]] && FONT_ARG=(-font "$FONT")

mkdir -p "$GEN"

# 1. Transparent logo: flood-fill the white background from each corner
#    (leaves the white lettering inside the badge untouched).
"$IM" "$SRC" -resize 1024x1024 -alpha set -fuzz 12% -fill none \
  -draw "color 0,0 floodfill" -draw "color %[fx:w-1],0 floodfill" \
  -draw "color 0,%[fx:h-1] floodfill" -draw "color %[fx:w-1],%[fx:h-1] floodfill" \
  -trim +repage "$GEN/logo.png" 2>/dev/null || \
"$IM" "$SRC" -resize 1024x1024 -alpha set -fuzz 12% -fill none \
  -floodfill +0+0 white -trim +repage "$GEN/logo.png"

# 2. Icons
for s in 48 128 256 512; do
  d="$INC/usr/share/icons/hicolor/${s}x${s}/apps"; mkdir -p "$d"
  "$IM" "$GEN/logo.png" -resize "${s}x${s}" -background none -gravity center -extent "${s}x${s}" "$d/cisa-logo.png"
done

# 3. Wallpaper (navy gradient, logo, tagline)
make_wallpaper() {  # make_wallpaper <WxH> <out>
  local size=$1 out=$2 w=${1%x*} h=${1#*x}
  local logo=$(( h * 30 / 100 )) pt=$(( h * 28 / 1000 ))
  "$IM" -size "$size" "radial-gradient:${NAVY}-${INK}" \
    \( "$GEN/logo.png" -resize "${logo}x${logo}" \) -gravity center -geometry "+0-$(( h / 14 ))" -composite \
    "${FONT_ARG[@]}" -pointsize "$pt" -fill "$PAPER" -gravity center \
    -annotate "+0+$(( logo / 2 + h / 18 ))" "$TAGLINE" \
    "$out"
}
WP="$INC/usr/share/wallpapers/CISA"
mkdir -p "$WP/contents/images"
make_wallpaper 1920x1080 "$WP/contents/images/1920x1080.png"
make_wallpaper 3840x2160 "$WP/contents/images/3840x2160.png"
make_wallpaper 1366x768  "$WP/contents/images/1366x768.png"
cp "$WP/contents/images/1920x1080.png" "$WP/contents/screenshot.png"
cat > "$WP/metadata.json" <<'EOF'
{ "KPlugin": { "Id": "CISA", "Name": "CISA", "Authors": [ { "Name": "CISA - Penn State Abington" } ], "License": "CC-BY-SA-4.0" } }
EOF

# 4. Boot menu splash. GRUB and ISOLINUX only read 8-bit RGB PNGs (16-bit/alpha renders as garbage).
#    The live ISO's GRUB runs at 800x600; ISOLINUX must be exactly 640x480.
mkdir -p "$GEN/boot"
"$IM" -size 800x600 "radial-gradient:${NAVY}-${INK}" \
  \( "$GEN/logo.png" -resize 150x150 \) -gravity north -geometry +0+40 -composite \
  -background "$NAVY" -alpha remove -alpha off -depth 8 "PNG24:$GEN/boot/grub-splash.png"
"$IM" -size 640x480 "radial-gradient:${NAVY}-${INK}" \
  \( "$GEN/logo.png" -resize 110x110 \) -gravity north -geometry +0+20 -composite \
  -background "$NAVY" -alpha remove -alpha off -depth 8 "PNG24:$GEN/boot/isolinux-splash.png"

# 5. Installer (Calamares) images
CB="$INC/etc/calamares/branding/cisa"; mkdir -p "$CB"
cp "$INC/usr/share/icons/hicolor/256x256/apps/cisa-logo.png" "$CB/logo.png"
"$IM" -size 800x440 "radial-gradient:${NAVY}-${INK}" \
  \( "$GEN/logo.png" -resize 200x200 \) -gravity north -geometry +0+40 -composite \
  "${FONT_ARG[@]}" -pointsize 30 -fill "$PAPER" -gravity south -annotate +0+60 "Welcome to CISA Linux" \
  "$CB/welcome.png"

echo "Branding generated (accent $ACCENT)."
