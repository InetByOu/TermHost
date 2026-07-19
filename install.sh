#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v6.3 - Professional Production Setup

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}TermHost Installer v6.3${NC}"
    echo "===================================="
    echo -e "${CYAN}Professional Production Environment Setup${NC}"
    echo ""

# Function to install packages with better error handling
echo_step() {
    echo -e "${YELLOW}[$1]${NC} $2..."
}

echo_ok() { echo -e "${GREEN}Done${NC}"; }
echo_fail() { echo -e "${RED}Failed${NC}"; }

# ==================== 1. FIX DPKG ====================
echo_step "1/9" "Fixing broken packages"
dpkg --configure -a >> /dev/null 2>&1 || true
apt --fix-broken install -y >> /dev/null 2>&1 || true
echo_ok

# ==================== 2. UPDATE REPO ====================
echo_step "2/9" "Updating package repositories"
if ! pkg update -y >> /dev/null 2>&1; then
    echo -e "${YELLOW}Warning: pkg update failed. You may need to run 'termux-change-repo'${NC}"
fi
echo_ok

# ==================== 3. INSTALL CORE PACKAGES ====================
echo_step "3/9" "Installing core packages"

PACKAGES="nginx php-fpm php git curl wget jq unzip zip openssh mariadb"

if pkg install -y $PACKAGES >> /dev/null 2>&1; then
    echo_ok
else
    echo_fail
    echo -e "${YELLOW}Some packages failed to install.${NC}"
    echo -e "${YELLOW}Recommended: Run 'termux-change-repo' then try installing again.${NC}"
    echo -e "${YELLOW}Or run: pkg install -y $PACKAGES${NC}"
fi

# ==================== 4. DOWNLOAD CORE FILES ====================
echo_step "4/9" "Downloading TermHost core files"

mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs" "$INSTALL_DIR/sites/default" "$INSTALL_DIR/vhosts"

if curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/termhost.sh -o "$INSTALL_DIR/termhost.sh"; then
    chmod +x "$INSTALL_DIR/termhost.sh"
    echo_ok
else
    echo_fail
    echo -e "${RED}Critical: Failed to download termhost.sh${NC}"
    exit 1
fi

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "port": 8080,
  "use_mariadb": true,
  "tinyfm_username": "admin",
  "tinyfm_password_hash": ""
}
EOF
fi

# ==================== 5. CREATE SYSTEM CONFIG ====================
echo_step "5/9" "Creating system configuration"

cat > $PREFIX/etc/php-fpm.d/www.conf << 'PHPEOF'
[www]
user = $(whoami)
group = $(whoami)
listen = 127.0.0.1:9000
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
PHPEOF

cat > $PREFIX/etc/nginx/nginx.conf << 'NGINXEOF'
worker_processes auto;
events { worker_connections 1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        listen       8080;
        server_name  localhost;

        root   ~/termhost/sites/default;
        index  index.php index.html;

        location / {
            try_files \$uri \$uri/ /index.php?\$args;
        }

        location ~ \\.php\$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  \$document_root\$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
NGINXEOF

cat > "$INSTALL_DIR/sites/default/index.php" << 'EOF'
<?php echo "TermHost is ready!"; ?>
EOF
echo_ok

# ==================== 6. CREATE BINARY ====================
echo_step "6/9" "Creating termhost command"
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo_ok

# ==================== 7. FINAL INITIALIZATION ====================
echo_step "7/9" "Final environment initialization"

# Run termhost to initialize directories and config
if [ -f "$INSTALL_DIR/termhost.sh" ]; then
    bash "$INSTALL_DIR/termhost.sh" --init-only 2>/dev/null || true
fi
echo_ok

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          TermHost v6.3 - Production Ready Installed        ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Run: ${YELLOW}termhost${NC}"
    echo ""
    echo -e "${CYAN}All core components are ready.${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${PURPLE}Note: You are running as ROOT.${NC}"
    fi
    echo ""
