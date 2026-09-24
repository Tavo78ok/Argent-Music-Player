#!/bin/bash
set -e

VERSION="1.1.0"
PKG="argent-music-player"
APP_DIR="AppDir"

echo "▶ Preparando AppDir..."

mkdir -p "$APP_DIR/usr/bin"
mkdir -p "$APP_DIR/usr/share/$PKG"
mkdir -p "$APP_DIR/usr/share/applications"
mkdir -p "$APP_DIR/usr/share/icons/hicolor/256x256/apps"

# ── Archivo principal
cp argent_music_player.py "$APP_DIR/usr/share/$PKG/"

# ── AppRun
cat > "$APP_DIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=$(dirname "$SELF")
export PYTHONPATH="$HERE/usr/lib/python3:$PYTHONPATH"
exec python3 "$HERE/usr/share/argent-music-player/argent_music_player.py" "$@"
EOF
chmod +x "$APP_DIR/AppRun"

# ── .desktop
cat > "$APP_DIR/$PKG.desktop" << 'EOF'
[Desktop Entry]
Name=Argent Music Player
GenericName=Reproductor de música
Comment=Reproductor de música local con letras sincronizadas y ecualizador
Exec=argent-music-player
Icon=argent-music-player
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Music;Player;GTK;
MimeType=audio/mpeg;audio/flac;audio/ogg;audio/opus;audio/x-wav;audio/mp4;
StartupWMClass=argent-music-player
EOF

cp "$APP_DIR/$PKG.desktop" "$APP_DIR/usr/share/applications/"

# ── Icono
cat > /tmp/argent-music-player.svg << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <radialGradient id="bg" cx="50%" cy="40%" r="55%">
      <stop offset="0%" stop-color="#3584e4"/>
      <stop offset="100%" stop-color="#1a5fb4"/>
    </radialGradient>
  </defs>
  <circle cx="32" cy="32" r="31" fill="url(#bg)"/>
  <rect x="26" y="18" width="4" height="18" rx="2" fill="white"/>
  <rect x="34" y="14" width="4" height="18" rx="2" fill="white"/>
  <rect x="26" y="18" width="12" height="4" rx="2" fill="white"/>
  <ellipse cx="24" cy="37" rx="6" ry="4" fill="white"/>
  <ellipse cx="32" cy="33" rx="6" ry="4" fill="white"/>
</svg>
EOF

echo "▶ Generando icono PNG..."
PNG_DEST="$APP_DIR/usr/share/icons/hicolor/256x256/apps/$PKG.png"
if command -v rsvg-convert &>/dev/null; then
    rsvg-convert -w 256 -h 256 /tmp/argent-music-player.svg -o "$PNG_DEST"
elif command -v inkscape &>/dev/null; then
    inkscape --export-type=png --export-width=256 --export-height=256 \
             --export-filename="$PNG_DEST" /tmp/argent-music-player.svg 2>/dev/null
elif command -v convert &>/dev/null; then
    convert -background none -resize 256x256 /tmp/argent-music-player.svg "$PNG_DEST" 2>/dev/null
fi

if [ -f "$PNG_DEST" ]; then
    cp "$PNG_DEST" "$APP_DIR/$PKG.png"
    echo "  ✓ Icono generado"
else
    echo "  ⚠ No se pudo generar PNG — instala rsvg-convert: sudo apt install librsvg2-bin"
    python3 -c "
import struct, zlib
def make_png(w,h,color):
    def chunk(t,d): return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
    sig=b'\x89PNG\r\n\x1a\n'
    ihdr=chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))
    r,g,b=color
    raw=b''.join(b'\x00'+bytes([r,g,b]*w) for _ in range(h))
    idat=chunk(b'IDAT',zlib.compress(raw))
    iend=chunk(b'IEND',b'')
    return sig+ihdr+idat+iend
open('$APP_DIR/$PKG.png','wb').write(make_png(256,256,(53,132,228)))
open('$PNG_DEST','wb').write(make_png(256,256,(53,132,228)))
print('  ✓ Icono placeholder generado')
"
fi

# ── appimagetool
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    echo "▶ Descargando appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage"
    chmod +x appimagetool-x86_64.AppImage
    echo "  ✓ appimagetool descargado"
fi

# ── Construir AppImage
echo "▶ Construyendo AppImage..."
ARCH=x86_64 ./appimagetool-x86_64.AppImage "$APP_DIR" "${PKG}_${VERSION}_x86_64.AppImage" 2>/dev/null

if [ -f "${PKG}_${VERSION}_x86_64.AppImage" ]; then
    chmod +x "${PKG}_${VERSION}_x86_64.AppImage"
    echo ""
    echo "✅ ${PKG}_${VERSION}_x86_64.AppImage generado"
    echo "   Ejecutar: ./${PKG}_${VERSION}_x86_64.AppImage"
else
    echo "❌ Error generando AppImage"
    echo "   Verificá: ./appimagetool-x86_64.AppImage --help"
fi
