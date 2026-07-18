#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v2.4 - Root Aware

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TermHost Installer v2.4                  ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

# Root Detection during install
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${PURPLE}[INFO] Running as ROOT user${NC}"
    echo -e "${YELLOW}Some features will be enabled for root.${NC}"
    echo ""
fi

echo -e "${YELLOW}[1/6]${NC} Updating packages..."
pkg update -y && pkg upgrade -y

echo -e "${YELLOW}[2/6]${NC} Installing packages..."
pkg install -y nginx php-fpm php php-mysql mariadb git curl wget jq

echo -e "${YELLOW}[3/6]${NC} Setting up TermHost..."
if [ -d "$INSTALL_DIR" ]; then
    cd "$INSTALL_DIR" && git pull
else
    git clone https://github.com/InetByOu/TermHost.git "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR"/vhosts "$INSTALL_DIR"/logs

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "use_mariadb": true
}
EOF
fi

echo -e "${YELLOW}[4/6]${NC} Configuring services..."

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

mkdir -p "$INSTALL_DIR/sites/default"
cat > "$INSTALL_DIR/sites/default/index.php" << 'EOF'
<?php echo "TermHost Ready"; ?>
EOF

echo -e "${YELLOW}[5/6]${NC} Creating command..."
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"

echo -e "${YELLOW}[6/6]${NC} Starting services..."
pkill nginx 2>/dev/null || true
pkill php-fpm 2>/dev/null || true
pkill mysqld 2>/dev/null || true

php-fpm >/dev/null 2>&1
nginx >/dev/null 2>&1

if [ "$(jq -r '.use_mariadb' $INSTALL_DIR/config/config.json 2>/dev/null)" = "true" ]; then
    mysqld_safe --datadir=$PREFIX/var/lib/mysql >/dev/null 2>&1 &
fi

echo ""
echo -e "${GREEN}TermHost installed successfully!${NC}"
if [ "$(id -u)" -eq 0 ]; then
    echo -e "${PURPLE}Running as ROOT - Extra features enabled.${NC}"
fi
echo -e "Run: ${YELLOW}termhost${NC}"
