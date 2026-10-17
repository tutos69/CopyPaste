#!/bin/bash
# One-line installer for CopyPaste:
#   curl -fsSL https://raw.githubusercontent.com/tutos69/CopyPaste/main/install.sh | bash
set -euo pipefail

REPO="tutos69/CopyPaste"
URL="https://github.com/$REPO/releases/latest/download/CopyPaste.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Descargando CopyPaste..."
curl -fsSL "$URL" -o "$TMP/CopyPaste.zip"
ditto -x -k "$TMP/CopyPaste.zip" "$TMP"

pkill -x CopyPaste 2>/dev/null || true
rm -rf /Applications/CopyPaste.app
mv "$TMP/CopyPaste.app" /Applications/
# The app is not notarized by Apple; drop the quarantine flag so macOS lets it open.
xattr -dr com.apple.quarantine /Applications/CopyPaste.app 2>/dev/null || true

open /Applications/CopyPaste.app
echo "Listo: CopyPaste está instalado y abierto (ícono de portapapeles en la barra de menú)."
echo "Activa 'Abrir al iniciar sesión' en su menú para que arranque sola con la Mac."
