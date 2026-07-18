#!/data/data/com.termux/files/usr/bin/bash

# TermHost - Termux Web Hosting Manager
# One-Run Installer

set -e

echo "===================================="
echo "   TermHost Installer - Termux"
echo "===================================="
echo ""

echo "[1/6] Updating packages..."
pkg update -y && pkg upgrade -y

echo "[2/6] Installing required packages..."
pkg install -y nginx php-fpm php php-mysql mariadb git curl wget unzip jq

echo "[3/6] Setting up directories..."
mkdir -p ~/termhost/sites
mkdir -p ~/termhost/config
mkdir -p ~/termhost/logs
mkdir -p ~/termhost/modules

# Create default config
echo '{
  "default_site": "default",
  "web_root": "~/termhost/sites",
  "php_version": "8.2",
  "use_mariadb": true
}' > ~/termhost/config/config.json

echo "[4/6] Configuring Nginx..."
# Backup original if exists
if [ -f $PREFIX/etc/nginx/nginx.conf ]; then
    cp $PREFIX/etc/nginx/nginx.conf $PREFIX/etc/nginx/nginx.conf.bak
fi

# Create simple nginx config for TermHost
cat > $PREFIX/etc/nginx/nginx.conf << 'NGINXEOF'
worker_processes 1;
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

echo "[5/6] Starting services for first time..."
# Start php-fpm
pkill php-fpm || true
php-fpm &

# Start nginx
pkill nginx || true
nginx

echo "[6/6] Installation completed!"
echo ""
echo "===================================="
echo " Installation finished successfully!"
echo "===================================="
echo ""
echo "Run the manager using:"
echo "  bash ~/termhost/termhost.sh"
echo ""