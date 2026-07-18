#!/data/data/com.termux/files/usr/bin/bash

# TermHost Upgrade Script v1.0
# Lightweight upgrade - only downloads core files + compatibility check

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

# Check if TermHost is installed
if [ ! -f "$INSTALL_DIR/termhost.sh" ]; then
    echo -e "${RED}TermHost is not installed!${NC}"
    echo "Please install first using:"
    echo "curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash"
    exit 1
fi

# Get current version
CURRENT_VERSION=$(grep -o 'VERSION="[0-9.]*"' "$INSTALL_DIR/termhost.sh" | head -1 | cut -d'"' -f2)
if [ -z "$CURRENT_VERSION" ]; then
    CURRENT_VERSION="unknown"
fi

echo -e "Current installed version: ${YELLOW}v${CURRENT_VERSION}${NC}"
    echo ""

# Download latest termhost.sh to check version
    echo -e "${YELLOW}Checking latest version from GitHub...${NC}"
    
    LATEST_SCRIPT=$(curl -fsSL "$GITHUB_RAW/termhost.sh" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$LATEST_SCRIPT" ]; then
        echo -e "${RED}Failed to connect to GitHub.${NC}"
        echo "Please check your internet connection."
        exit 1
    fi
    
    LATEST_VERSION=$(echo "$LATEST_SCRIPT" | grep -o 'VERSION="[0-9.]*"' | head -1 | cut -d'"' -f2)
    
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION="unknown"
    fi
    
    echo -e "Latest version available:  ${GREEN}v${LATEST_VERSION}${NC}"
    echo ""
    
    # Compare versions
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        echo -e "${GREEN}You already have the latest version!${NC}"
        read -p "Press enter to exit..."
        exit 0
    fi
    
    echo -e "${YELLOW}New version available!${NC}"
    echo ""
    
    # Show what will be updated
    echo -e "${CYAN}This upgrade will:${NC}"
    echo "  - Download latest termhost.sh (core script)"
    echo "  - Keep your existing configuration (config.json)"
    echo "  - Keep all your websites in sites/ folder"
    echo "  - Update the termhost command"
    echo ""
    
    read -p "Continue with upgrade? [Y/n]: " confirm
    
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Upgrade cancelled.${NC}"
        exit 0
    fi
    
    echo ""
    echo -e "${YELLOW}Starting upgrade...${NC}"
    
    # Backup current termhost.sh
    BACKUP_FILE="$INSTALL_DIR/termhost.sh.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$INSTALL_DIR/termhost.sh" "$BACKUP_FILE"
    echo -e "  ${GREEN}✓${NC} Backup created: $(basename "$BACKUP_FILE")"
    
    # Download new termhost.sh
    echo "$LATEST_SCRIPT" > "$INSTALL_DIR/termhost.sh"
    chmod +x "$INSTALL_DIR/termhost.sh"
    echo -e "  ${GREEN}✓${NC} termhost.sh updated to v${LATEST_VERSION}"
    
    # Update symlink
    if [ -L "$BIN_PATH" ]; then
        rm -f "$BIN_PATH"
    fi
    ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
    echo -e "  ${GREEN}✓${NC} Command updated"
    
    echo ""
    echo -e "${GREEN}Upgrade completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}Changes:${NC}"
    echo "  - Old version backed up to: $(basename "$BACKUP_FILE")"
    echo "  - New version: v${LATEST_VERSION}"
    echo "  - Your websites and config are preserved"
    echo ""
    echo -e "${YELLOW}Please restart TermHost to use the new version.${NC}"
    echo ""
    read -p "Press enter to finish..."
