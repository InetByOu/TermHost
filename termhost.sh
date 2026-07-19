#!/data/data/com.termux/files/usr/bin/bash

# TermHost v7.0 - Clean Production Version

VERSION="7.0"

if [ "$(id -u)" -eq 0 ]; then
    REAL_HOME="/data/data/com.termux/files/home"
    [ -f "$REAL_HOME/.suroot/termhost/termhost.sh" ] && REAL_HOME="$REAL_HOME/.suroot"
else
    REAL_HOME="$HOME"
fi

CONFIG="$REAL_HOME/termhost/config/config.json"
SITES_DIR="$REAL_HOME/termhost/sites"
LOG_DIR="$REAL_HOME/termhost/logs"
VHOST_DIR="$REAL_HOME/termhost/vhosts"
STORAGE_DIR="$REAL_HOME/storage"
INSTALL_DIR="$REAL_HOME/termhost"
TINYFM_URL="https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php"

init() {
    mkdir -p "$SITES_DIR" "$VHOST_DIR" "$LOG_DIR" "$INSTALL_DIR/config"
    [ ! -f "$CONFIG" ] && cat > "$CONFIG" << 'EOF'
{
  "port": 8080,
  "use_mariadb": true,
  "tinyfm_username": "admin",
  "tinyfm_password_hash": ""
}
EOF
}

get_port() { jq -r '.port // 8080' "$CONFIG" 2>/dev/null || echo 8080; }

is_root() { [ "$(id -u)" -eq 0 ]; }

handle_error() { echo -e "${RED}[Error]${NC} $1"; sleep 1.5; }

backup_config() {
    [ -f "$1" ] && cp "$1" "${1}.bak.$(date +%s)" 2>/dev/null || true
}

print_header() {
    if is_root; then
        echo -e "${PURPLE}TermHost v${VERSION}${NC} - Root | Port: $(get_port)"
    else
        echo -e "${BLUE}TermHost v${VERSION}${NC} | Port: $(get_port)"
    fi
    echo "===================================="
}

show_status() {
    local port=$(get_port)
    echo -e "${CYAN}=== Status ===${NC}"
    pgrep -x nginx >/dev/null && echo -e "  Nginx   : ${GREEN}Running${NC} (:$port)" || echo -e "  Nginx   : ${RED}Stopped${NC}"
    pgrep -x php-fpm >/dev/null && echo -e "  PHP-FPM : ${GREEN}Running${NC}" || echo -e "  PHP-FPM : ${RED}Stopped${NC}"
    pgrep -x mysqld >/dev/null && echo -e "  MariaDB : ${GREEN}Running${NC}" || echo -e "  MariaDB : ${RED}Stopped${NC}"
    is_root && echo -e "  Mode    : ${PURPLE}ROOT${NC}" || echo -e "  Mode    : ${CYAN}Normal${NC}"
    echo ""
}

show_menu() {
    echo -e "${YELLOW}Menu:${NC}"
    echo "  1) Create Website        8) Database"
    echo "  2) Create from Storage   9) Fix Permissions"
    echo "  3) List Websites        10) Change Port"
    echo "  4) Delete Website       11) File Manager Settings"
    echo "  5) Start Services       12) Upgrade TermHost"
    echo "  6) Stop Services        13) Termux:Boot (Root)"
    echo "  7) Setup Tunnel         14) Swap (Root)"
    echo "  0) Exit"
    echo ""
}

install_tinyfm() {
    local path="$1" name="$2"
    mkdir -p "$path/adminfm"
    [ ! -f "$path/adminfm/index.php" ] && \
    curl -fsSL "$TINYFM_URL" -o "$path/adminfm/index.php" 2>/dev/null || true
}

create_website() {
    read -p "Website name: " name
    [ -z "$name" ] && { handle_error "Name required"; return; }
    [ -d "$SITES_DIR/$name" ] && { handle_error "Already exists"; return; }

    mkdir -p "$SITES_DIR/$name"
    echo "<?php echo \"<h1>Welcome to $name</h1>\"; ?>" > "$SITES_DIR/$name/index.php"

    cat > "$VHOST_DIR/$name.conf" << EOF
server {
    listen $(get_port);
    server_name $name.localhost;
    root $SITES_DIR/$name;
    index index.php index.html;
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \\.php\$ {
        fastcgi_pass 127.0.0.1:9000;
        include fastcgi_params;
    }
}
EOF

    echo "127.0.0.1 $name.localhost" >> $PREFIX/etc/hosts 2>/dev/null || true
    install_tinyfm "$SITES_DIR/$name" "$name"
    nginx -s reload 2>/dev/null || true

    echo -e "${GREEN}Created: http://$name.localhost:$(get_port)${NC}"
    echo -e "${CYAN}File Manager: http://$name.localhost:$(get_port)/adminfm${NC}"
}

list_websites() {
    echo -e "${YELLOW}Websites:${NC}"
    ls "$SITES_DIR" 2>/dev/null | while read s; do
        [ -d "$SITES_DIR/$s" ] && echo "  → $s → http://$s.localhost:$(get_port)"
    done
    echo ""
}

delete_website() {
    list_websites
    read -p "Website to delete: " name
    [ -z "$name" ] && return

    echo -e "${RED}Type DELETE to confirm:${NC}"
    read -p "> " confirm
    [ "$confirm" != "DELETE" ] && { echo "Cancelled"; return; }

    rm -rf "$SITES_DIR/$name" "$VHOST_DIR/$name.conf"
    sed -i "/$name.localhost/d" $PREFIX/etc/hosts 2>/dev/null || true
    nginx -s reload 2>/dev/null || true

    echo -e "${GREEN}Deleted: $name${NC}"
}

start_services() {
    pkill nginx php-fpm mysqld 2>/dev/null || true
    sleep 1

    php-fpm -t >/dev/null 2>&1 || { handle_error "PHP-FPM config error"; return; }
    php-fpm >/dev/null 2>&1 || { handle_error "Failed to start PHP-FPM"; return; }
    nginx >/dev/null 2>&1 || { handle_error "Failed to start Nginx"; return; }

    echo -e "${GREEN}Services started.${NC}"
}

stop_services() {
    pkill nginx php-fpm mysqld 2>/dev/null || true
    echo -e "${RED}Services stopped.${NC}"
}

setup_tunnel() {
    ensure_log_dir
    echo "1) Ngrok  2) Cloudflare  3) localhost.run"
    read -p "Choose: " c
    case $c in
        1) command -v ngrok >/dev/null || pkg install ngrok -y; ngrok http $(get_port) > $LOG_DIR/ngrok.log 2>&1 & ;;
        2) command -v cloudflared >/dev/null || pkg install cloudflared -y; cloudflared tunnel --url http://localhost:$(get_port) > $LOG_DIR/cloudflare.log 2>&1 & ;;
        3) ssh -R 80:localhost:$(get_port) nokey@localhost.run > $LOG_DIR/localhostrun.log 2>&1 & ;;
    esac
}

file_manager_settings() {
    echo -e "${YELLOW}File Manager Settings${NC}"
    echo "1) Change Username  2) Change Password (hashed)  3) Show Settings  0) Back"
    read -p "Choose: " opt
    case $opt in
        1) read -p "New username: " u; [ -n "$u" ] && jq ".tinyfm_username = \"$u\"" "$CONFIG" > tmp && mv tmp "$CONFIG" ;;
        2) read -p "New password: " p; [ -n "$p" ] && h=$(php -r "echo password_hash('$p', PASSWORD_DEFAULT);"); jq ".tinyfm_password_hash = \"$h\"" "$CONFIG" > tmp && mv tmp "$CONFIG" ;;
        3) echo "Username: $(get_tinyfm_username) | Password: Hashed";;
    esac
}

main() {
    init
    while true; do
        clear
        print_header
        show_status
        show_menu
        read -p "Select: " c
        case $c in
            1) create_website ;;
            3) list_websites ;;
            4) delete_website ;;
            5) start_services ;;
            6) stop_services ;;
            7) setup_tunnel ;;
            10) change_port ;;
            11) file_manager_settings ;;
            12) upgrade_termhost ;;
            0) exit 0 ;;
            *) echo "Invalid" ;;
        esac
        read -p "Press Enter..."
    done
}

main