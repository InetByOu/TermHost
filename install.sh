#!/data/data/com.termux/files/usr/bin/bash

# TermHost Installer v7.5 - Download Binaries at Install Time

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_DIR="$HOME/termhost"
BIN_PATH="$PREFIX/bin/termhost"
GITHUB_REPO="InetByOu/TermHost"
GITHUB_RELEASE_TAG="binaries-v1.0"

clear
echo -e "${BLUE}TermHost Installer v7.5${NC}"
    echo "===================================="
    echo -e "${CYAN}Binaries downloaded during installation${NC}"
    echo ""

echo_step() { echo -e "${YELLOW}[$1]${NC} $2..."; }
echo_ok() { echo -e "${GREEN}Done${NC}"; }

get_system_arch() {
    local arch=$(uname -m)
    case $arch in
        aarch64|arm64) echo "arm64" ;;
        armv7l|armhf)  echo "arm" ;;
        x86_64|amd64)  echo "amd64" ;;
        *)             echo "arm64" ;;
    esac
}

# Download binary from GitHub Releases
download_binary() {
    local name="$1"
    local arch=$(get_system_arch)
    local filename="${name}-${arch}"
    local dest="$INSTALL_DIR/bin/$name"

    echo -e "${YELLOW}Downloading $name for $arch...${NC}"

    local url="https://github.com/${GITHUB_REPO}/releases/download/${GITHUB_RELEASE_TAG}/${filename}"

    if curl -fsSL "$url" -o "$dest"; then
        chmod +x "$dest"
        echo -e "  ${GREEN}✓ $name downloaded${NC}"
    else
        echo -e "  ${RED}✗ Failed to download $name${NC}"
    fi
}

# 1. Fix system
echo_step "1/7" "Fixing package system"
dpkg --configure -a >> /dev/null 2>&1 || true
apt --fix-broken install -y >> /dev/null 2>&1 || true
echo_ok

# 2. Update
echo_step "2/7" "Updating repositories"
pkg update -y >> /dev/null 2>&1 || true
echo_ok

# 3. Install packages
echo_step "3/7" "Installing packages"
pkg install -y nginx php-fpm php git curl wget jq unzip zip openssh mariadb >> /dev/null 2>&1 || true
echo_ok

# 4. Download TermHost core
echo_step "4/7" "Downloading TermHost core"
mkdir -p "$INSTALL_DIR/config" "$INSTALL_DIR/logs" "$INSTALL_DIR/sites/default" "$INSTALL_DIR/vhosts" "$INSTALL_DIR/bin"

curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/termhost.sh -o "$INSTALL_DIR/termhost.sh"
chmod +x "$INSTALL_DIR/termhost.sh"
echo_ok

# 5. Download static binaries
echo_step "5/7" "Downloading static binaries (ngrok & cloudflared)"
download_binary "ngrok"
download_binary "cloudflared"
echo_ok

# 6. Default config
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

# 7. Configure services & create command
echo_step "6/7" "Configuring services"

cat > $PREFIX/etc/php-fpm.d/www.conf << 'PHPEOF'
[www]
user=$(whoami)
group=$(whoami)
listen=127.0.0.1:9000
pm=dynamic
pm.max_children=5
pm.start_servers=2
pm.min_spare_servers=1
pm.max_spare_servers=3
PHPEOF

cat > $PREFIX/etc/nginx/nginx.conf << 'NGINXEOF'
worker_processes auto;
events { worker_connections 1024; }
http {
    include mime.types;
    default_type application/octet-stream;
    server {
        listen 8080;
        server_name localhost;
        root ~/termhost/sites/default;
        index index.php index.html;
        location / { try_files \$uri \$uri/ /index.php?\$args; }
        location ~ \\.php\$ {
            fastcgi_pass 127.0.0.1:9000;
            include fastcgi_params;
        }
    }
}
NGINXEOF

cat > "$INSTALL_DIR/sites/default/index.php" << 'EOF'
<?php echo "TermHost is ready!"; ?>
EOF
echo_ok

# Create command
echo_step "7/7" "Creating termhost command"
chmod +x "$INSTALL_DIR/termhost.sh"
if [ -L "$BIN_PATH" ]; then rm -f "$BIN_PATH"; fi
ln -s "$INSTALL_DIR/termhost.sh" "$BIN_PATH"
echo_ok

echo ""
echo -e "${GREEN}TermHost v7.5 installed successfully!${NC}"
    echo -e "Run: ${YELLOW}termhost${NC}"
    echo -e "${CYAN}Binaries (ngrok & cloudflared) have been downloaded.${NC}"
