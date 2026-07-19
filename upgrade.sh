#!/data/data/com.termux/files/usr/bin/bash

# TermHost Upgrade Script v1.0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"
GITHUB_RAW="https://raw.githubusercontent.com/InetByOu/TermHost/main"

clear
echo -e "${BLUE}TermHost Upgrade Tool${NC}"
    echo "===================================="
    echo ""

if [ ! -f "$INSTALL_DIR/termhost.sh" ]; then
    echo -e "${RED}TermHost is not installed!${NC}"
    exit 1
fi

CURRENT_VERSION=$(grep -o 'VERSION="[0-9.]*"' "$INSTALL_DIR/termhost.sh" | head -1 | cut -d'"' -f2)
if [ -z "$CURRENT_VERSION" ]; then CURRENT_VERSION="unknown"; fi

echo -e "Current installed version: ${YELLOW}v${CURRENT_VERSION}${NC}"
    echo ""

LATEST_SCRIPT=$(curl -fsSL "$GITHUB_RAW/termhost.sh" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$LATEST_SCRIPT" ]; then
    echo -e "${RED}Failed to connect to GitHub.${NC}"
    exit 1
fi

LATEST_VERSION=$(echo "$LATEST_SCRIPT" | grep -o 'VERSION="[0-9.]*"' | head -1 | cut -d'"' -f2)
if [ -z "$LATEST_VERSION" ]; then LATEST_VERSION="unknown"; fi

echo -e "Latest version available:  ${GREEN}v${LATEST_VERSION}${NC}"
    echo ""

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo -e "${GREEN}You already have the latest version!${NC}"
    read -p "Press enter to exit..."
    exit 0
fi

echo -e "${YELLOW}New version available!${NC}"
    echo ""

echo -e "${CYAN}This upgrade will:${NC}"
    echo "  - Download latest termhost.sh"
    echo "  - Keep your existing configuration and websites"
    echo "  - Update the termhost command"
    echo ""

read -p "Continue with upgrade? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Upgrade cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting upgrade...${NC}"

BACKUP_FILE="$INSTALL_DIR/termhost.sh.bak.$(date +%Y%m%d_%H%M%S)"
cp "$INSTALL_DIR/termhost.sh" "$BACKUP_FILE"
echo -e "  ${GREEN}✓${NC} Backup created"

echo "$LATEST_SCRIPT" > "$INSTALL_DIR/termhost.sh"
chmod +x "$INSTALL_DIR/termhost.sh"
echo -e "  ${GREEN}✓${NC} termhost.sh updated to v${LATEST_VERSION}"

if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo -e "  ${GREEN}✓${NC} Command updated"

echo ""
echo -e "${GREEN}Upgrade completed successfully!${NC}"
    echo ""
    read -p "Press enter to finish..."
