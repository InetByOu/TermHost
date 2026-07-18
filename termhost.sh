#!/data/data/com.termux/files/usr/bin/bash

# TermHost v3.1 - Improved Process Management

CONFIG="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"
VHOST_DIR="$HOME/termhost/vhosts"
STORAGE_DIR="$HOME/storage"
BOOT_DIR="$HOME/.termux/boot"
SWAP_FILE="/data/swapfile"

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

has_magisk() {
    [ -d "/data/adb/magisk" ]
}

get_total_ram_mb() {
    free -m | awk '/^Mem:/ {print $2}'
}

handle_error() {
    echo -e "${RED}[Error]${NC} $1"
    read -p "Press enter to continue..."
}

# ==================== SAFE PROCESS MANAGEMENT ====================

stop_service() {
    local service=$1
    if pgrep -x "$service" >/dev/null 2>&1; then
        pkill -x "$service" 2>/dev/null || true
        sleep 1
    fi
}

stop_all_services() {
    echo -e "${YELLOW}Stopping all services...${NC}"
    stop_service nginx
    stop_service php-fpm
    stop_service mysqld
    
    # Stop tunnels
    pkill -f "ngrok http" 2>/dev/null || true
    pkill -f cloudflared 2>/dev/null || true
    pkill -f "ssh -R" 2>/dev/null || true
    
    echo -e "${GREEN}All services stopped.${NC}"
}

start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    
    # Stop first to avoid conflicts
    stop_all_services
    sleep 1

    # Start PHP-FPM
    if ! php-fpm >/dev/null 2>&1; then
        handle_error "Failed to start PHP-FPM"
        return 1
    fi

    sleep 1

    # Start Nginx
    if ! nginx >/dev/null 2>&1; then
        handle_error "Failed to start Nginx"
        return 1
    fi

    # Start MariaDB if enabled
    if [ "$(jq -r '.use_mariadb' $CONFIG 2>/dev/null)" = "true" ]; then
        if ! mysqld_safe --datadir=$PREFIX/var/lib/mysql >/dev/null 2>&1 & then
            echo -e "${YELLOW}Warning: Could not start MariaDB${NC}"
        fi
    fi

    echo -e "${GREEN}Services started successfully.${NC}"
}

stop_services() {
    stop_all_services
}

is_service_running() {
    local service=$1
    pgrep -x "$service" >/dev/null 2>&1
}

# ==================== HEADER & STATUS ====================

print_header() {
    clear
    if is_root; then
        echo -e "${PURPLE}TermHost v3.1${NC} - Root Mode"
    else
        echo -e "${BLUE}TermHost v3.1${NC}"
    fi
    echo "===================================="
    echo ""
}

show_status() {
    echo -e "${CYAN}Service Status:${NC}"
    
    if is_service_running nginx; then
        echo -e "  Nginx      : ${GREEN}Running${NC}"
    else
        echo -e "  Nginx      : ${RED}Stopped${NC}"
    fi

    if is_service_running php-fpm; then
        echo -e "  PHP-FPM    : ${GREEN}Running${NC}"
    else
        echo -e "  PHP-FPM    : ${RED}Stopped${NC}"
    fi

    if is_service_running mysqld; then
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

    local ram=$(get_total_ram_mb)
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
    
    if is_root; then
        echo -e "  ${PURPLE}10) Termux:Boot Setup${NC}"
        echo -e "  ${PURPLE}11) Swap Management (Low RAM)${NC}"
    else
        echo "  10) Settings / Auto Start"
    fi
    
    echo "  0) Exit"
    echo ""
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

    echo -e "${GREEN}Website created: http://$name.localhost:8080${NC}"
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

    echo -e "${GREEN}Created from Storage!${NC}"
}

create_vhost() {
    local name=$1
    mkdir -p "$VHOST_DIR"
    cat > "$VHOST_DIR/$name.conf" << EOF
server {
    listen 8080;
    server_name $name.localhost;
    root $SITES_DIR/$name;
    index index.php index.html;
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \\.php\$ { fastcgi_pass 127.0.0.1:9000; include fastcgi_params; }
}
EOF
}

add_to_hosts() {
    echo "127.0.0.1 $1.localhost" >> "$PREFIX/etc/hosts" 2>/dev/null || true
}

list_websites() {
    echo -e "${YELLOW}Your Websites:${NC}"
    ls "$SITES_DIR" 2>/dev/null | while read s; do
        echo "  → $s → http://$s.localhost:8080"
    done
    echo ""
}

setup_tunnel() {
    echo "1) Ngrok  2) Cloudflare  3) localhost.run"
    read -p "Choose: " c
    case $c in
        1)
            read -p "Ngrok token: " t
            ngrok config add-authtoken "$t" 2>/dev/null || true
            pkill -f "ngrok http" 2>/dev/null || true
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            ;;
        2)
            pkill -f "ngrok http" 2>/dev/null || true
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            ;;
        3)
            pkill -f "ssh -R" 2>/dev/null || true
            ssh -o StrictHostKeyChecking=no -R 80:localhost:8080 nokey@localhost.run > $LOG_DIR/localhostrun.log 2>&1 &
            ;;
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

# ==================== AUTO SWAP ====================
create_swap() {
    local swap_size_mb=1024

    if [ -f "$SWAP_FILE" ]; then
        echo -e "${YELLOW}Swap already exists.${NC}"
        return
    fi

    echo -e "${YELLOW}Creating swap file...${NC}"

    if ! dd if=/dev/zero of="$SWAP_FILE" bs=1M count=$swap_size_mb status=progress 2>/dev/null; then
        handle_error "Failed to create swap file"
        return
    fi

    chmod 600 "$SWAP_FILE"
    mkswap "$SWAP_FILE" >/dev/null 2>&1
    swapon "$SWAP_FILE" 2>/dev/null || true

    echo -e "${GREEN}Swap created successfully.${NC}"
}

enable_swap_on_boot() {
    if has_magisk; then
        mkdir -p /data/adb/service.d
        cat > /data/adb/service.d/termhost_swap.sh << 'MAGISKEOF'
#!/system/bin/sh
SWAP_FILE="/data/swapfile"
if [ -f "$SWAP_FILE" ]; then
    swapon "$SWAP_FILE" 2>/dev/null || true
fi
MAGISKEOF
        chmod 755 /data/adb/service.d/termhost_swap.sh
        echo -e "${GREEN}Magisk service created.${NC}"
    else
        mkdir -p "$BOOT_DIR"
        echo "swapon $SWAP_FILE 2>/dev/null || true" >> "$BOOT_DIR/start-termhost.sh"
        chmod +x "$BOOT_DIR/start-termhost.sh"
        echo -e "${GREEN}Swap added to Termux:Boot.${NC}"
    fi
}

auto_setup_swap_if_low_ram() {
    if ! is_root; then return; fi

    local ram_mb=$(get_total_ram_mb)

    if [ "$ram_mb" -lt 2048 ]; then
        echo -e "${YELLOW}Low RAM detected (${ram_mb} MB)${NC}"
        read -p "Create swap file? (y/n): " ans
        if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
            create_swap
            enable_swap_on_boot
        fi
    else
        echo -e "${GREEN}RAM is sufficient (${ram_mb} MB).${NC}"
    fi
}

swap_management_menu() {
    if ! is_root; then
        echo -e "${RED}Root required.${NC}"
        return
    fi

    echo -e "${PURPLE}Swap Management:${NC}"
    echo "1) Check Current Swap"
    echo "2) Create Swap File"
    echo "3) Enable Swap on Boot"
    echo "4) Auto Setup (if RAM < 2GB)"
    echo "5) Back"
    read -p "Choose: " c

    case $c in
        1) swapon --show ; free -h ;;
        2) create_swap ;;
        3) enable_swap_on_boot ;;
        4) auto_setup_swap_if_low_ram ;;
        *)
            return
            ;;
    esac
}

# ==================== TERMUX BOOT ====================
setup_termux_boot() {
    if ! is_root; then
        echo -e "${RED}Root only.${NC}"
        return
    fi

    echo -e "${PURPLE}Termux:Boot Setup:${NC}"
    read -p "Start Nginx? (y/n): " n1
    read -p "Start PHP-FPM? (y/n): " n2
    read -p "Start MariaDB? (y/n): " n3

    mkdir -p "$BOOT_DIR"

    cat > "$BOOT_DIR/start-termhost.sh" << BOOTEOF
#!/data/data/com.termux/files/usr/bin/bash
sleep 12
pkill nginx 2>/dev/null || true
pkill php-fpm 2>/dev/null || true
pkill mysqld 2>/dev/null || true
BOOTEOF

    [[ "$n1" == "y" || "$n1" == "Y" ]] && echo "nginx >/dev/null 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"
    [[ "$n2" == "y" || "$n2" == "Y" ]] && echo "php-fpm >/dev/null 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"
    [[ "$n3" == "y" || "$n3" == "Y" ]] && echo "mysqld_safe --datadir=\u0024PREFIX/var/lib/mysql >/dev/null 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"

    chmod +x "$BOOT_DIR/start-termhost.sh"
    echo -e "${GREEN}Termux:Boot script created.${NC}"
}

root_boot_menu() {
    if ! is_root; then
        echo -e "${RED}Root required.${NC}"
        return
    fi

    echo -e "${PURPLE}Termux:Boot:${NC}"
    echo "1) Setup Termux:Boot"
    echo "2) Back"
    read -p "Choose: " c

    case $c in
        1) setup_termux_boot ;;
        *)
            return
            ;;
    esac
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
            10)
                if is_root; then
                    root_boot_menu
                else
                    settings_menu
                fi
                ;;
            11)
                if is_root; then
                    swap_management_menu
                else
                    echo -e "${RED}Invalid option${NC}"
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