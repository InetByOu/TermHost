#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v4.5 - Lightweight + Smart Update

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}TermHost Installer v4.5${NC}"
    echo "===================================="
    echo ""

# ==================== FIX BROKEN DPKG ====================
echo -e "${YELLOW}[1/6]${NC} Fixing broken packages..."
dpkg --configure -a >> /dev/null 2>&1 || true
apt --fix-broken install -y >> /dev/null 2>&1 || true
echo -e "${GREEN}Done${NC}"

# ==================== UPDATE PACKAGES ====================
echo -e "${YELLOW}[2/6]${NC} Updating package repositories..."
pkg update -y >> /dev/null 2>&1 || true
echo -e "${GREEN}Done${NC}"

# ==================== INSTALL CORE PACKAGES ====================
echo -e "${YELLOW}[3/6]${NC} Installing core packages..."

CORE="nginx php-fpm php git curl wget jq unzip"
if pkg install -y $CORE >> /dev/null 2>&1; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${RED}Failed to install core packages.${NC}"
    echo "Please run: pkg install -y $CORE"
    exit 1
fi

# MariaDB optional
echo -ne "${YELLOW}Installing MariaDB (optional)... ${NC}"
if pkg install -y mariadb >> /dev/null 2>&1; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${YELLOW}Skipped${NC}"
fi

# ==================== DOWNLOAD ONLY NEEDED FILES ====================
echo -e "${YELLOW}[4/6]${NC} Downloading TermHost (script + config only)..."

mkdir -p "$INSTALL_DIR/config"

# Download termhost.sh
if curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/termhost.sh -o "$INSTALL_DIR/termhost.sh"; then
    chmod +x "$INSTALL_DIR/termhost.sh"
    echo -e "  ${GREEN}✓${NC} termhost.sh downloaded"
else
    echo -e "  ${RED}✗${NC} Failed to download termhost.sh"
    exit 1
fi

# Create default config if not exists
if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
    echo -e "  ${GREEN}✓${NC} Default config created"
else
    echo -e "  ${YELLOW}✓${NC} Existing config kept"
fi

echo -e "${GREEN}Done${NC}"

# ==================== CREATE DIRECTORIES ====================
echo -e "${YELLOW}[5/6]${NC} Creating directories..."
mkdir -p "$INSTALL_DIR/sites/default" "$INSTALL_DIR/vhosts" "$INSTALL_DIR/logs"
mkdir -p "$PREFIX/etc/nginx" "$PREFIX/etc/php-fpm.d"
echo -e "${GREEN}Done${NC}"

# ==================== CONFIGURE SERVICES ====================
echo -e "${YELLOW}[6/6]${NC} Configuring Nginx and PHP-FPM..."

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

# Create / update binary
echo -e "${YELLOW}Creating termhost command...${NC}"
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"

echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "Run: ${YELLOW}termhost${NC}"
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${PURPLE}Running as ROOT - Extra features enabled.${NC}"
fi
