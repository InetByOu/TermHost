#!/data/data/com.termux/files/usr/bin/bash

# TermHost v2 - Full One-Run Installer
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}====================================${NC}"
echo -e "${YELLOW}   TermHost v2 - Installer${NC}"
echo -e "${YELLOW}====================================${NC}"

echo -e "\n[1/7] Updating Termux packages..."
pkg update -y && pkg upgrade -y

echo -e "[2/7] Installing core packages..."
pkg install -y nginx php-fpm php php-mysql mariadb git curl wget jq unzip termux-api

echo -e "[3/7] Creating directory structure..."
mkdir -p $HOME/termhost/{sites,config,logs,modules,backups}

if [ ! -f $HOME/termhost/config/config.json ]; then
cat > $HOME/termhost/config/config.json << 'EOF'
{
  "default_port": 8080,
  "web_root": "~/termhost/sites",
  "use_mariadb": true,
  "php_version": "8.2",
  "cloudflare_tunnel_token": "",
  "ngrok_token": ""
}
EOF
fi

echo -e "[4/7] Configuring Nginx + PHP-FPM..."

# PHP-FPM config
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

# Nginx main config
cat > $PREFIX/etc/nginx/nginx.conf << 'NGINXEOF'
worker_processes auto;
events { worker_connections 1024; }

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       8080;
        server_name  localhost;

        root   ~/termhost/sites/default;
        index  index.php index.html index.htm;

        location / {
            try_files $uri $uri/ /index.php?$args;
        }

        location ~ \.php$ {
            fastcgi_pass   127.0.0.1:9000;
            fastcgi_index  index.php;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            include        fastcgi_params;
        }
    }
}
NGINXEOF

mkdir -p $HOME/termhost/sites/default
cat > $HOME/termhost/sites/default/index.php << 'EOF'
<?php echo "<h1>TermHost is working!</h1>"; phpinfo(); ?>
EOF

echo -e "[5/7] Initializing MariaDB..."
if [ ! -d $PREFIX/var/lib/mysql ]; then
    mariadb-install-db --user=$(whoami) --datadir=$PREFIX/var/lib/mysql
fi

echo -e "[6/7] Starting services..."
pkill nginx 2>/dev/null || true
pkill php-fpm 2>/dev/null || true
pkill mysqld 2>/dev/null || true

php-fpm &
sleep 1
nginx

if [ "$(jq -r '.use_mariadb' $HOME/termhost/config/config.json)" = "true" ]; then
    mysqld_safe --datadir=$PREFIX/var/lib/mysql &
fi

echo -e "[7/7] Installation completed!"
echo -e "\n${GREEN}====================================${NC}"
echo -e "${GREEN} Installation finished successfully!${NC}"
echo -e "${GREEN}====================================${NC}"
echo -e "\nRun: ${YELLOW}bash ~/termhost/termhost.sh${NC}"
