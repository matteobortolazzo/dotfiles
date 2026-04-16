#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/.local/share/pencil"
SYMLINK="$HOME/.local/bin/pencil"

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <path-to-Pencil-linux-x64.tar>"
    exit 1
fi

tarball="$1"

if [[ ! -f "$tarball" ]]; then
    echo "Error: '$tarball' not found"
    exit 1
fi

# Find the top-level directory name inside the tarball
top_dir=$(tar tf "$tarball" | head -1 | cut -d/ -f1 || true)
if [[ -z "$top_dir" ]]; then
    echo "Error: could not determine tarball structure"
    exit 1
fi

echo "Installing $top_dir to $INSTALL_DIR..."

# Extract to a temp dir, then move into place
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

tar xf "$tarball" -C "$tmpdir"

# Remove old installation and move new one in
rm -rf "$INSTALL_DIR"
mv "$tmpdir/$top_dir" "$INSTALL_DIR"
chmod +x "$INSTALL_DIR/pencil" "$INSTALL_DIR/chrome-sandbox" "$INSTALL_DIR/chrome_crashpad_handler"

# Create symlink
mkdir -p "$(dirname "$SYMLINK")"
rm -rf "$SYMLINK"
ln -s "$INSTALL_DIR/pencil" "$SYMLINK"

# Install desktop entry
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/pencil.desktop" <<EOF
[Desktop Entry]
Name=Pencil
Comment=Design on canvas. Land in code.
Exec=$INSTALL_DIR/pencil
Icon=$INSTALL_DIR/resources/app/icon.png
Type=Application
Categories=Development;Graphics;
StartupWMClass=Pencil
EOF

echo "Installed: $top_dir"
echo "Binary:    $SYMLINK -> $INSTALL_DIR/pencil"
