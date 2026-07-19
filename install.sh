#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v7.0 - Clean Production Setup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}TermHost Installer v7.0${NC}"
    echo "===================================="
    echo -e "${CYAN}Clean Production Environment${NC}"
    echo ""

echo_step() { echo -e "${YELLOW}[$1]${NC} $2..."; }
echo_ok()   { echo -e "${GREEN}Done${NC}"; }

# 1. Fix dpkg
echo_step "1/7" "Fixing package system"
dpkg --configure -a >> /dev/null 2>&1 || true
apt --fix-broken install -y >> /dev/null 2>&1 || true
echo_ok

# 2. Update repositories
echo_step "2/7" "Updating repositories"
pkg update -y >> /dev/null 2>&1 || true
echo_ok

# 3. Install core packages
echo_step "3/7" "Installing core packages"
CORE="nginx php-fpm php git curl wget jq unzip zip openssh mariadb"
if pkg install -y $CORE >> /dev/null 2>&1; then
    echo_ok
else
    echo -e "${YELLOW}Warning: Some packages failed. Consider running 'termux-change-repo'${NC}"
fi

# 4. Download TermHost
echo_step "4/7" "Downloading TermHost"
mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs" "$INSTALL_DIR/sites/default" "$INSTALL_DIR/vhosts"

curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/termhost.sh -o "$INSTALL_DIR/termhost.sh"
chmod +x "$INSTALL_DIR/termhost.sh"

echo_ok

# 5. Create default config
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

# 6. Configure services
echo_step "5/7" "Configuring services"

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

# 7. Create binary
echo_step "6/7" "Creating command"
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo_ok

# Final
echo_step "7/7" "Finalizing"
echo_ok

echo ""
echo -e "${GREEN}TermHost v7.0 installed successfully!${NC}"
    echo -e "Run: ${YELLOW}termhost${NC}"
