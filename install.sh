#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v6.1 - Full Production Environment

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}TermHost Installer v6.1 - Production Ready${NC}"
    echo "===================================="
    echo ""

# ==================== FIX BROKEN DPKG ====================
echo -e "${YELLOW}[1/8]${NC} Fixing broken packages..."
dpkg --configure -a >> /dev/null 2>&1 || true
apt --fix-broken install -y >> /dev/null 2>&1 || true
echo -e "${GREEN}Done${NC}"

# ==================== UPDATE & UPGRADE ====================
echo -e "${YELLOW}[2/8]${NC} Updating package repositories..."
pkg update -y >> /dev/null 2>&1 || true
echo -e "${GREEN}Done${NC}"

# ==================== INSTALL CORE + SUPPORTING PACKAGES ====================
echo -e "${YELLOW}[3/8]${NC} Installing core + supporting packages..."

# Core packages
CORE="nginx php-fpm php git curl wget jq unzip zip openssh"

if pkg install -y $CORE >> /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Core packages installed"
else
    echo -e "  ${RED}✗${NC} Some core packages failed"
fi

# MariaDB (optional but recommended)
echo -ne "  ${YELLOW}Installing MariaDB... ${NC}"
if pkg install -y mariadb >> /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}Skipped${NC}"
fi

# ==================== DOWNLOAD CORE FILES ====================
echo -e "${YELLOW}[4/8]${NC} Downloading TermHost core files..."

mkdir -p "$INSTALL_DIR/config"

if curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/termhost.sh -o "$INSTALL_DIR/termhost.sh"; then
    chmod +x "$INSTALL_DIR/termhost.sh"
    echo -e "  ${GREEN}✓${NC} termhost.sh downloaded"
else
    echo -e "  ${RED}✗${NC} Failed to download termhost.sh"
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
    echo -e "  ${GREEN}✓${NC} Default config created"
fi

echo -e "${GREEN}Done${NC}"

# ==================== CREATE ALL DIRECTORIES ====================
echo -e "${YELLOW}[5/8]${NC} Creating complete directory structure..."

mkdir -p "$INSTALL_DIR/sites/default" \
           "$INSTALL_DIR/vhosts" \
           "$INSTALL_DIR/logs" \
           "$INSTALL_DIR/config"

mkdir -p "$PREFIX/etc/nginx" \
           "$PREFIX/etc/php-fpm.d"

echo -e "  ${GREEN}✓${NC} All directories created"
echo -e "${GREEN}Done${NC}"

# ==================== CONFIGURE SERVICES ====================
echo -e "${YELLOW}[6/8]${NC} Configuring Nginx and PHP-FPM..."

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
echo -e "${GREEN}Done${NC}"

# ==================== CREATE BINARY ====================
echo -e "${YELLOW}[7/8]${NC} Creating termhost command..."
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo -e "${GREEN}Done${NC}"

# ==================== FINAL INITIALIZATION ====================
echo -e "${YELLOW}[8/8]${NC} Final initialization..."

# Run termhost once to initialize directories and config
bash "$INSTALL_DIR/termhost.sh" --init-only 2>/dev/null || true

echo -e "${GREEN}Done${NC}"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     TermHost v6.1 - Production Ready Installed       ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "You can now run: ${YELLOW}termhost${NC}"
    echo ""
    echo -e "${CYAN}Everything is ready. Just run 'termhost' and start creating websites.${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${PURPLE}Running as ROOT - Some features enabled.${NC}"
    fi
