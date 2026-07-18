#!/data/data/com.termux/files/usr/bin/bash

# TermHost - One Command Installer
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/install.sh | bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"

clear
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║           TermHost - One Command Installer           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

echo -e "${YELLOW}[1/6]${NC} Updating Termux packages..."
pkg update -y && pkg upgrade -y

echo -e "${YELLOW}[2/6]${NC} Installing required packages..."
pkg install -y nginx php-fpm php php-mysql mariadb git curl wget jq unzip

echo -e "${YELLOW}[3/6]${NC} Creating TermHost directory..."
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}TermHost directory already exists. Updating...${NC}"
    cd "$INSTALL_DIR"
    git pull
else
    git clone https://github.com/InetByOu/TermHost.git "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

echo -e "${YELLOW}[4/6]${NC} Setting up configuration..."
mkdir -p "$INSTALL_DIR"/vhosts
mkdir -p "$INSTALL_DIR"/logs

if [ ! -f "$INSTALL_DIR/config/config.json" ]; then
    cat > "$INSTALL_DIR/config/config.json" << 'EOF'
{
  "default_port": 8080,
  "web_root": "~/termhost/sites",
  "use_mariadb": true
}
EOF
fi

echo -e "${YELLOW}[5/6]${NC} Configuring Nginx & PHP-FPM..."

# PHP-FPM
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

# Nginx
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
<?php echo "<h1>TermHost is ready!</h1>"; ?>
EOF

echo -e "${YELLOW}[6/6]${NC} Making TermHost command available..."

# Make termhost.sh executable
chmod +x "$INSTALL_DIR/termhost.sh"

# Create symlink so user can run 'termhost' directly
if [ -L "$BIN_PATH" ]; then
    rm -f "$BIN_PATH"
fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"

# Start services for first time
echo -e "${YELLOW}Starting services for the first time...${NC}"
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
    echo -e "You can now run TermHost using: ${YELLOW}termhost${NC}"
    echo ""
    echo -e "${CYAN}Quick Start:${NC}"
    echo "  termhost                # Open interactive menu"
    echo "  termhost --help         # (coming soon)"
    echo ""