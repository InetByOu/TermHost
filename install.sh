#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v3.9 - Full Repository Download

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}TermHost Installer v3.9${NC}"
    echo "===================================="
    echo ""

# Function to print status
echo_step() {
    echo -e "${YELLOW}[$1]${NC} $2..."
}

echo_ok() {
    echo -e "${GREEN}OK${NC}"
}

echo_fail() {
    echo -e "${RED}FAILED${NC}"
}

# ==================== 1. FIX BROKEN DPKG ====================
echo_step "1/8" "Fixing broken packages"
dpkg --configure -a >> /dev/null 2>&1 || true
apt --fix-broken install -y >> /dev/null 2>&1 || true
echo_ok

# ==================== 2. UPDATE PACKAGES ====================
echo_step "2/8" "Updating package repositories"
pkg update -y >> /dev/null 2>&1 || true
echo_ok

# ==================== 3. INSTALL PACKAGES ====================
echo_step "3/8" "Installing required packages"

if pkg install -y nginx php-fpm php php-pdo git curl wget jq unzip mariadb >> /dev/null 2>&1; then
    echo_ok
else
    echo_fail
    echo -e "${YELLOW}Trying to recover...${NC}"
    dpkg --configure -a >> /dev/null 2>&1 || true
    apt --fix-broken install -y >> /dev/null 2>&1 || true
    
    if pkg install -y nginx php-fpm php php-pdo git curl wget jq unzip mariadb >> /dev/null 2>&1; then
        echo_ok
    else
        echo -e "${RED}Failed to install packages.${NC}"
        echo "Please run manually: pkg install -y nginx php-fpm php php-pdo git curl wget jq unzip mariadb"
        exit 1
    fi
fi

# ==================== 4. DOWNLOAD FULL REPOSITORY FROM GITHUB ====================
echo_step "4/8" "Downloading full TermHost project from GitHub"

echo -e "${CYAN}This will download termhost.sh + all supporting directories (sites, vhosts, config, logs, etc.)${NC}"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Updating existing installation...${NC}"
    cd "$INSTALL_DIR" && git pull >> /dev/null 2>&1 || true
else
    if ! git clone https://github.com/InetByOu/TermHost.git "$INSTALL_DIR" >> /dev/null 2>&1; then
        echo_fail
        echo -e "${RED}Failed to download from GitHub.${NC}"
        echo -e "Please check your internet connection."
        exit 1
    fi
fi
echo_ok

# Verify that termhost.sh exists
if [ ! -f "$INSTALL_DIR/termhost.sh" ]; then
    echo -e "${RED}Critical Error: termhost.sh was not downloaded from GitHub!${NC}"
    exit 1
fi

# Verify supporting directories exist
if [ ! -d "$INSTALL_DIR/sites" ] || [ ! -d "$INSTALL_DIR/config" ]; then
    echo -e "${RED}Critical Error: Supporting directories were not downloaded properly!${NC}"
    exit 1
fi

# ==================== 5. CREATE DIRECTORIES ====================
echo_step "5/8" "Creating additional directories"
mkdir -p "$INSTALL_DIR/sites/default" "$INSTALL_DIR/vhosts" "$INSTALL_DIR/logs" "$INSTALL_DIR/config"
mkdir -p "$PREFIX/etc/nginx" "$PREFIX/etc/php-fpm.d"
echo_ok

# ==================== 6. CREATE CONFIG ====================
echo_step "6/8" "Creating default configuration"

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
fi
echo_ok

# ==================== 7. CONFIGURE SERVICES ====================
echo_step "7/8" "Configuring Nginx and PHP-FPM"

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

# ==================== 8. CREATE BINARY ====================
echo_step "8/8" "Creating termhost command"
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo_ok

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
echo -e "${GREEN}Installation completed successfully!${NC}"
echo -e "Run: ${YELLOW}termhost${NC}"
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${PURPLE}Running as ROOT - Extra features enabled.${NC}"
fi
