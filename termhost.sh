#!/data/data/com.termux/files/usr/bin/bash

# TermHost v5.5 - Add Delete Website Feature

VERSION="5.5"

CONFIG="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"
VHOST_DIR="$HOME/termhost/vhosts"
STORAGE_DIR="$HOME/storage"
INSTALL_DIR="$HOME/termhost"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

is_root() { [ "$(id -u)" -eq 0 ]; }
has_storage() { [ -d "$STORAGE_DIR" ]; }
get_port() { jq -r '.port // 8080' "$CONFIG" 2>/dev/null || echo 8080; }

handle_error() {
    echo -e "${RED}[Error]${NC} $1"
    sleep 1.5
}

print_header() {
    if is_root; then
        echo -e "${PURPLE}TermHost v${VERSION}${NC} - Root Mode | Port: $(get_port)"
    else
        echo -e "${BLUE}TermHost v${VERSION}${NC} | Port: $(get_port)"
    fi
    echo "===================================="
}

show_status() {
    local port=$(get_port)
    echo -e "${CYAN}=== Service Status ===${NC}"
    
    if pgrep -x nginx >/dev/null; then
        echo -e "  Nginx      : ${GREEN}● Running${NC} (:$port)"
    else
        echo -e "  Nginx      : ${RED}● Stopped${NC}"
    fi

    if pgrep -x php-fpm >/dev/null; then
        echo -e "  PHP-FPM    : ${GREEN}● Running${NC}"
    else
        echo -e "  PHP-FPM    : ${RED}● Stopped${NC}"
    fi

    if pgrep -x mysqld >/dev/null; then
        echo -e "  MariaDB    : ${GREEN}● Running${NC}"
    else
        echo -e "  MariaDB    : ${RED}● Stopped${NC}"
    fi

    if is_root; then
        echo -e "  Mode       : ${PURPLE}ROOT${NC}"
    else
        echo -e "  Mode       : ${CYAN}Normal${NC}"
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
    echo -e "${CYAN}=== Active Public URLs ===${NC}"
    local has_url=false

    if [ -f $LOG_DIR/ngrok.log ]; then
        url=$(grep -o 'https://[a-zA-Z0-9-]*\.ngrok.io' $LOG_DIR/ngrok.log | tail -1)
        if [ -n "$url" ]; then
            echo -e "  Ngrok      : ${GREEN}$url${NC}"
            has_url=true
        fi
    fi

    if [ -f $LOG_DIR/cloudflare.log ]; then
        url=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare.com' $LOG_DIR/cloudflare.log | tail -1)
        if [ -n "$url" ]; then
            echo -e "  Cloudflare : ${GREEN}$url${NC}"
            has_url=true
        fi
    fi

    if [ "$has_url" = false ]; then
        echo -e "  ${YELLOW}(No active public tunnel)${NC}"
    fi
    echo ""
}

main_menu() {
    echo -e "${YELLOW}Main Menu:${NC}"
    echo "  1) Create New Website (Virtual Host)"
    echo "  2) Create Website from SD Card / Storage"
    echo "  3) List All Websites"
    echo "  4) Delete Website"
    echo "  5) Start All Services"
    echo "  6) Stop All Services"
    echo "  7) Setup Online Tunnel"
    echo "  8) View Status & Active Public URLs"
    echo "  9) Database Management"
    echo "  10) Fix Permissions & Errors"
    echo "  11) Change Port"
    echo "  12) Upgrade TermHost"
    
    if is_root; then
        echo -e "  ${PURPLE}13) Termux:Boot Setup${NC}"
        echo -e "  ${PURPLE}14) Swap Management (Low RAM)${NC}"
    fi
    
    echo "  0) Exit"
    echo ""
}

upgrade_termhost() {
    if [ -f "$INSTALL_DIR/upgrade.sh" ]; then
        bash "$INSTALL_DIR/upgrade.sh"
    else
        echo -e "${YELLOW}Downloading upgrade tool...${NC}"
        curl -fsSL https://raw.githubusercontent.com/InetByOu/TermHost/main/upgrade.sh -o /tmp/upgrade.sh
        bash /tmp/upgrade.sh
        rm -f /tmp/upgrade.sh
    fi
}

change_port() {
    local current_port=$(get_port)
    echo -e "${YELLOW}Current Port: $current_port${NC}"
    read -p "New port: " new_port

    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
        handle_error "Invalid port number"
        return
    fi

    if [ "$new_port" -lt 1024 ] && ! is_root; then
        handle_error "Non-root users cannot use ports below 1024 (try 8080 or higher)"
        return
    fi

    backup_config "$PREFIX/etc/nginx/nginx.conf"

    if [ -f "$CONFIG" ]; then
        jq ".port = $new_port" "$CONFIG" > "${CONFIG}.tmp" 2>/dev/null && mv "${CONFIG}.tmp" "$CONFIG"
    else
        mkdir -p "$(dirname "$CONFIG")"
        echo "{ \"port\": $new_port, \"use_mariadb\": true }" > "$CONFIG"
    fi

    if [ -f "$PREFIX/etc/nginx/nginx.conf" ]; then
        sed -i "s/listen .*;/listen       $new_port;/" $PREFIX/etc/nginx/nginx.conf
    fi

    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null || true
    fi

    echo -e "${GREEN}Port changed to $new_port successfully!${NC}"
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
    echo "127.0.0.1 $1.localhost" >> "$PREFIX/etc/hosts" 2>/dev/null || true
}

list_websites() {
    local port=$(get_port)
    echo -e "${YELLOW}Your Websites:${NC}"
    
    if [ ! -d "$SITES_DIR" ] || [ -z "$(ls -A $SITES_DIR 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}(No websites found)${NC}"
        echo ""
        return
    fi

    ls "$SITES_DIR" 2>/dev/null | while read s; do
        if [ -d "$SITES_DIR/$s" ] || [ -L "$SITES_DIR/$s" ]; then
            echo "  → $s → http://$s.localhost:$port"
        fi
    done
    echo ""
}

delete_website() {
    echo -e "${YELLOW}Delete Website (Purge Mode)${NC}"
    echo ""
    
    if [ ! -d "$SITES_DIR" ] || [ -z "$(ls -A $SITES_DIR 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}(No websites to delete)${NC}"
        echo ""
        read -p "Press enter to continue..."
        return
    fi

    echo -e "${CYAN}Available websites:${NC}"
    local i=1
    local websites=()
    
    while IFS= read -r site; do
        if [ -d "$SITES_DIR/$site" ] || [ -L "$SITES_DIR/$site" ]; then
            websites+=("$site")
            echo "  $i) $site"
            ((i++))
        fi
    done < <(ls "$SITES_DIR" 2>/dev/null)

    if [ ${#websites[@]} -eq 0 ]; then
        echo -e "  ${YELLOW}(No websites found)${NC}"
        echo ""
        read -p "Press enter to continue..."
        return
    fi

    echo ""
    read -p "Select website number to delete (or 0 to cancel): " num

    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -eq 0 ]; then
        echo -e "${YELLOW}Cancelled.${NC}"
        return
    fi

    if [ "$num" -lt 1 ] || [ "$num" -gt ${#websites[@]} ]; then
        handle_error "Invalid selection"
        return
    fi

    local selected="${websites[$((num-1))]}"

    echo ""
    echo -e "${RED}WARNING: This will permanently delete:${NC}"
    echo "  - Website directory: $SITES_DIR/$selected"
    echo "  - Virtual host config: $VHOST_DIR/$selected.conf"
    echo "  - hosts entry for $selected.localhost"
    echo ""
    read -p "Type 'DELETE' to confirm: " confirm

    if [ "$confirm" != "DELETE" ]; then
        echo -e "${YELLOW}Deletion cancelled.${NC}"
        return
    fi

    echo ""
    echo -e "${YELLOW}Deleting website '$selected'...${NC}"

    # Remove website directory
    if [ -d "$SITES_DIR/$selected" ] || [ -L "$SITES_DIR/$selected" ]; then
        rm -rf "$SITES_DIR/$selected"
        echo -e "  ${GREEN}✓${NC} Removed directory: $selected"
    fi

    # Remove virtual host config
    if [ -f "$VHOST_DIR/$selected.conf" ]; then
        rm -f "$VHOST_DIR/$selected.conf"
        echo -e "  ${GREEN}✓${NC} Removed vhost config: $selected.conf"
    fi

    # Remove from /etc/hosts
    if [ -f "$PREFIX/etc/hosts" ]; then
        sed -i "/127.0.0.1 $selected.localhost/d" "$PREFIX/etc/hosts" 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} Removed hosts entry"
    fi

    # Reload Nginx
    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null || true
        echo -e "  ${GREEN}✓${NC} Nginx reloaded"
    fi

    echo ""
    echo -e "${GREEN}Website '$selected' has been completely deleted.${NC}"
    read -p "Press enter to continue..."
}

start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true

    sleep 1

    if ! php-fpm >/dev/null 2>&1; then
        handle_error "Failed to start PHP-FPM. Check config or port 9000."
        return 1
    fi

    sleep 1

    if ! nginx >/dev/null 2>&1; then
        handle_error "Failed to start Nginx. Check port $(get_port) or config."
        return 1
    fi

    if [ "$(jq -r '.use_mariadb' $CONFIG 2>/dev/null)" = "true" ]; then
        mysqld_safe --datadir=$PREFIX/var/lib/mysql >/dev/null 2>&1 &
    fi

    echo -e "${GREEN}Services started successfully.${NC}"
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

main() {
    while true; do
        clear
        print_header
        show_status
        show_active_domains
        main_menu

        read -p "Select option: " choice

        case $choice in
            1) create_website ;;
            2) create_from_storage ;;
            3) list_websites ;;
            4) delete_website ;;
            5) start_services ;;
            6) stop_services ;;
            7) setup_tunnel ;;
            8) show_status; show_active_domains ;;
            9) database_menu ;;
            10) fix_permissions ;;
            11) change_port ;;
            12) upgrade_termhost ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

main