#!/data/data/com.termux/files/usr/bin/bash

# TermHost v4.5 - Add Change Port Feature

CONFIG="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"
VHOST_DIR="$HOME/termhost/vhosts"
STORAGE_DIR="$HOME/storage"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

is_root() {
    [ "$(id -u)" -eq 0 ]
}

has_storage() {
    [ -d "$STORAGE_DIR" ]
}

get_port() {
    if [ -f "$CONFIG" ]; then
        jq -r '.port // 8080' "$CONFIG" 2>/dev/null || echo 8080
    else
        echo 8080
    fi
}

handle_error() {
    echo -e "${RED}[Error]${NC} $1"
    read -p "Press enter to continue..."
}

print_header() {
    clear
    if is_root; then
        echo -e "${PURPLE}TermHost v4.5${NC} - Root Mode"
    else
        echo -e "${BLUE}TermHost v4.5${NC}"
    fi
    echo "===================================="
    echo ""
}

show_status() {
    local port=$(get_port)
    echo -e "${CYAN}Service Status:${NC}"
    
    if pgrep -x nginx >/dev/null; then
        echo -e "  Nginx      : ${GREEN}Running${NC} (Port $port)"
    else
        echo -e "  Nginx      : ${RED}Stopped${NC}"
    fi

    if pgrep -x php-fpm >/dev/null; then
        echo -e "  PHP-FPM    : ${GREEN}Running${NC}"
    else
        echo -e "  PHP-FPM    : ${RED}Stopped${NC}"
    fi

    if pgrep -x mysqld >/dev/null; then
        echo -e "  MariaDB    : ${GREEN}Running${NC}"
    else
        echo -e "  MariaDB    : ${RED}Stopped${NC}"
    fi

    if is_root; then
        echo -e "  Mode       : ${PURPLE}ROOT${NC}"
    else
        echo -e "  Mode       : ${CYAN}Normal User${NC}"
    fi

    if has_storage; then
        echo -e "  Storage    : ${GREEN}Available${NC}"
    else
        echo -e "  Storage    : ${YELLOW}Not Setup${NC}"
    fi

    local ram=$(free -m | awk '/^Mem:/ {print $2}')
    echo -e "  RAM        : ${ram} MB"
    echo ""
}

show_active_domains() {
    echo -e "${CYAN}Active Public URLs:${NC}"
    
    if [ -f $LOG_DIR/ngrok.log ]; then
        url=$(grep -o 'https://[a-zA-Z0-9-]*\.ngrok.io' $LOG_DIR/ngrok.log | tail -1)
        [ ! -z "$url" ] && echo -e "  Ngrok      : ${GREEN}$url${NC}"
    fi

    if [ -f $LOG_DIR/cloudflare.log ]; then
        url=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare.com' $LOG_DIR/cloudflare.log | tail -1)
        [ ! -z "$url" ] && echo -e "  Cloudflare : ${GREEN}$url${NC}"
    fi
    echo ""
}

main_menu() {
    echo -e "${YELLOW}Main Menu:${NC}"
    echo "  1) Create New Website (Virtual Host)"
    echo "  2) Create Website from SD Card / Storage"
    echo "  3) List All Websites"
    echo "  4) Start All Services"
    echo "  5) Stop All Services"
    echo "  6) Setup Online Tunnel"
    echo "  7) View Status & Active Public URLs"
    echo "  8) Database Management"
    echo "  9) Fix Permissions & Errors"
    echo "  10) Change Port"
    
    if is_root; then
        echo -e "  ${PURPLE}11) Termux:Boot Setup${NC}"
        echo -e "  ${PURPLE}12) Swap Management (Low RAM)${NC}"
    else
        echo "  11) Settings / Auto Start"
    fi
    
    echo "  0) Exit"
    echo ""
}

change_port() {
    local current_port=$(get_port)
    echo -e "${YELLOW}Current Port: ${current_port}${NC}"
    read -p "Enter new port (e.g. 8080, 3000, 80): " new_port

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
        handle_error "Invalid port number"
        return
    fi

    # Update config.json
    if [ -f "$CONFIG" ]; then
        jq ".port = $new_port" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG"
    else
        echo "{ \"port\": $new_port }" > "$CONFIG"
    fi

    # Update Nginx config
    sed -i "s/listen .*;/listen       $new_port;/" $PREFIX/etc/nginx/nginx.conf

    # Reload Nginx if running
    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null || true
    fi

    echo -e "${GREEN}Port changed to $new_port successfully!${NC}"
    echo -e "${YELLOW}Please restart Nginx for changes to take full effect.${NC}"
}

create_website() {
    read -p "Website name: " name
    if [ -z "$name" ]; then
        handle_error "Name cannot be empty"
        return
    fi

    site_path="$SITES_DIR/$name"
    if [ -d "$site_path" ]; then
        handle_error "Website already exists"
        return
    fi

    mkdir -p "$site_path" || { handle_error "Failed to create folder"; return; }

    cat > "$site_path/index.php" << EOF
<?php echo "<h1>Welcome to $name</h1>"; ?>
EOF

    create_vhost "$name"
    add_to_hosts "$name"
    nginx -s reload 2>/dev/null || true

    local port=$(get_port)
    echo -e "${GREEN}Website created: http://$name.localhost:$port${NC}"
}

create_from_storage() {
    if ! has_storage; then
        echo -e "${YELLOW}Run 'termux-setup-storage' first${NC}"
        return
    fi

    echo "1) Download  2) DCIM  3) Pictures  4) Documents  5) Custom"
    read -p "Choose: " choice

    local path=""
    case $choice in
        1) path="$STORAGE_DIR/Download" ;;
        2) path="$STORAGE_DIR/DCIM" ;;
        3) path="$STORAGE_DIR/Pictures" ;;
        4) path="$STORAGE_DIR/Documents" ;;
        5) read -p "Folder: " f; path="$STORAGE_DIR/$f" ;;
        *) return ;;
    esac

    if [ ! -d "$path" ]; then
        handle_error "Folder not found"
        return
    fi

    read -p "Website name: " name
    site_path="$SITES_DIR/$name"

    ln -s "$path" "$site_path" || { handle_error "Failed to create symlink"; return; }

    create_vhost "$name"
    add_to_hosts "$name"
    nginx -s reload 2>/dev/null || true

    local port=$(get_port)
    echo -e "${GREEN}Created from Storage! Access: http://$name.localhost:$port${NC}"
}

create_vhost() {
    local name=$1
    local port=$(get_port)
    mkdir -p "$VHOST_DIR"
    cat > "$VHOST_DIR/$name.conf" << EOF
server {
    listen $port;
    server_name $name.localhost;

    root $SITES_DIR/$name;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \\.php\$ {
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
}

add_to_hosts() {
    local name=$1
    echo "127.0.0.1 $1.localhost" >> "$PREFIX/etc/hosts" 2>/dev/null || true
}

list_websites() {
    local port=$(get_port)
    echo -e "${YELLOW}Your Websites:${NC}"
    ls "$SITES_DIR" 2>/dev/null | while read s; do
        echo "  → $s → http://$s.localhost:$port"
    done
    echo ""
}

start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    stop_all_services
    sleep 1

    php-fpm >/dev/null 2>&1 || handle_error "Failed to start PHP-FPM"
    nginx >/dev/null 2>&1 || handle_error "Failed to start Nginx"

    if [ "$(jq -r '.use_mariadb' $CONFIG 2>/dev/null)" = "true" ]; then
        mysqld_safe --datadir=$PREFIX/var/lib/mysql >/dev/null 2>&1 &
    fi

    echo -e "${GREEN}Services started.${NC}"
}

stop_services() {
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true
    pkill -f "ngrok http" 2>/dev/null || true
    pkill -f cloudflared 2>/dev/null || true
    echo -e "${RED}All services stopped.${NC}"
}

setup_tunnel() {
    echo "1) Ngrok  2) Cloudflare  3) localhost.run"
    read -p "Choose: " c
    case $c in
        1) read -p "Token: " t; ngrok config add-authtoken "$t"; pkill -f "ngrok http" 2>/dev/null || true; ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 & ;;
        2) pkg install cloudflared -y; pkill -f cloudflared 2>/dev/null || true; cloudflared tunnel --url http://localhost:8080 > $LOG_DIR/cloudflare.log 2>&1 & ;;
        3) pkill -f "ssh -R" 2>/dev/null || true; ssh -o StrictHostKeyChecking=no -R 80:localhost:8080 nokey@localhost.run > $LOG_DIR/localhostrun.log 2>&1 & ;;
    esac
}

database_menu() {
    echo "1) Create DB  2) List DBs"
    read -p "Choose: " c
    case $c in
        1) read -p "DB Name: " db; mysql -u root -e "CREATE DATABASE $db;" ;;
        2) mysql -u root -e "SHOW DATABASES;" ;;
    esac
}

fix_permissions() {
    chmod -R 755 "$SITES_DIR" "$VHOST_DIR" 2>/dev/null || true
    echo -e "${GREEN}Permissions fixed.${NC}"
}

change_port() {
    local current_port=$(get_port)
    echo -e "${YELLOW}Current Port: $current_port${NC}"
    read -p "New port: " new_port

    if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1024 ] && ! is_root; then
        handle_error "Non-root users should use port >= 1024 (e.g. 8080)"
        return
    fi

    # Update config
    jq ".port = $new_port" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG" 2>/dev/null || echo "{ \"port\": $new_port }" > "$CONFIG"

    # Update Nginx config
    sed -i "s/listen .*;/listen       $new_port;/" $PREFIX/etc/nginx/nginx.conf

    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null || true
    fi

    echo -e "${GREEN}Port changed to $new_port successfully!${NC}"
}

main() {
    while true; do
        print_header
        show_status
        show_active_domains
        main_menu

        read -p "Select: " choice

        case $choice in
            1) create_website ;;
            2) create_from_storage ;;
            3) list_websites ;;
            4) start_services ;;
            5) stop_services ;;
            6) setup_tunnel ;;
            7) show_status; show_active_domains ;;
            8) database_menu ;;
            9) fix_permissions ;;
            10) change_port ;;
            11)
                if is_root; then
                    root_boot_menu
                else
                    settings_menu
                fi
                ;;
            12)
                if is_root; then
                    swap_management_menu
                fi
                ;;
            0) exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac

        echo ""
        read -p "Press Enter..."
    done
}

main