#!/data/data/com.termux/files/usr/bin/bash

# TermHost Upgrade v7.0

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/termhost.sh -o /tmp/termhost.sh
chmod +x /tmp/termhost.sh
cp /tmp/termhost.sh "$INSTALL_DIR/termhost.sh"
rm -f /tmp/termhost.sh

if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"

echo "TermHost upgraded successfully!"