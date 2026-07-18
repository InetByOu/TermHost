#!/data/data/com.termux/files/usr/bin/bash

# TermHost Smart Installer v3.5 - With Animation

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

# Spinner animation
function spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/\-'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%?}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TermHost Smart Installer v3.5            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

# ==================== FIX BROKEN DPKG ====================
echo -ne "${YELLOW}[1/7]${NC} Fixing broken packages... "
(dpdk --configure -a && apt --fix-broken install -y) >> /dev/null 2>&1 &
spinner $!
echo -e "${GREEN}Done${NC}"

# ==================== UPDATE & UPGRADE ====================
echo -ne "${YELLOW}[2/7]${NC} Updating package list... "
(pkg update -y) >> /dev/null 2>&1 &
spinner $!
echo -e "${GREEN}Done${NC}"

# ==================== INSTALL PACKAGES ====================
echo -e "${YELLOW}[3/7]${NC} Installing required packages..."

echo -ne "   - nginx, php-fpm, php, php-pdo... "
(pkg install -y nginx php-fpm php php-pdo git curl wget jq unzip mariadb) >> /dev/null 2>&1 &
spinner $!
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${RED}Failed${NC}"
    echo -e "${YELLOW}Trying to fix and retry...${NC}"
    dpkg --configure -a >> /dev/null 2>&1 || true
    apt --fix-broken install -y >> /dev/null 2>&1 || true
    (pkg install -y nginx php-fpm php php-pdo git curl wget jq unzip mariadb) >> /dev/null 2>&1 &
    spinner $!
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${RED}Failed${NC}"
        echo -e "${RED}Installation stopped due to package error.${NC}"
        exit 1
    fi
fi

# ==================== CREATE DIRECTORIES ====================
echo -ne "${YELLOW}[4/7]${NC} Creating directories... "
mkdir -p "$INSTALL_DIR/sites/default" "$INSTALL_DIR/vhosts" "$INSTALL_DIR/logs" "$INSTALL_DIR/config"
mkdir -p "$PREFIX/etc/nginx" "$PREFIX/etc/php-fpm.d"
echo -e "${GREEN}Done${NC}"

# ==================== CREATE CONFIG ====================
echo -ne "${YELLOW}[5/7]${NC} Creating default configuration... "
if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
fi
echo -e "${GREEN}Done${NC}"

# ==================== CONFIGURE SERVICES ====================
echo -ne "${YELLOW}[6/7]${NC} Configuring Nginx & PHP-FPM... "

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
echo -ne "${YELLOW}[7/7]${NC} Creating 'termhost' command... "
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo -e "${GREEN}Done${NC}"

# ==================== START SERVICES ====================
echo -e "${YELLOW}Starting services...${NC}"
pkill nginx 2>/dev/null || true
pkill php-fpm 2>/dev/null || true
pkill mysqld 2>/dev/null || true

php-fpm >/dev/null 2>&1
nginx >/dev/null 2>&1

if [ "$(jq -r '.use_mariadb' $INSTALL_DIR/config/config.json 2>/dev/null)" = "true" ]; then
    mysqld_safe --datadir=$PREFIX/var/lib/mysql >/dev/null 2>&1 &
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║     TermHost installed successfully!               ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "You can now run: ${YELLOW}termhost${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "${PURPLE}Running as ROOT - Extra features enabled.${NC}"
    fi
