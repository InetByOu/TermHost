#!/data/data/com.termux/files/usr/bin/bash

# TermHost v2.8 - Configurable Termux:Boot (Choose Services)

CONFIG="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"
VHOST_DIR="$HOME/termhost/vhosts"
STORAGE_DIR="$HOME/storage"
BOOT_DIR="$HOME/.termux/boot"

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

handle_error() {
    echo -e "${RED}Error: $1${NC}"
    read -p "Press enter to continue..."
}

print_header() {
    clear
    if is_root; then
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║   TermHost v2.8 - Configurable Termux:Boot           ║${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║           TermHost v2.8 - Web Hosting Manager        ║${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    fi
    echo ""
}

show_status() {
    echo -e "${CYAN}=== Service Status ===${NC}"
    
    if pgrep -x nginx >/dev/null; then
        echo -e "Nginx      : ${GREEN}● Running${NC}"
    else
        echo -e "Nginx      : ${RED}● Stopped${NC}"
    fi

    if pgrep -x php-fpm >/dev/null; then
        echo -e "PHP-FPM    : ${GREEN}● Running${NC}"
    else
        echo -e "PHP-FPM    : ${RED}● Stopped${NC}"
    fi

    if pgrep -x mysqld >/dev/null; then
        echo -e "MariaDB    : ${GREEN}● Running${NC}"
    else
        echo -e "MariaDB    : ${RED}● Stopped${NC}"
    fi

    if is_root; then
        echo -e "Mode       : ${PURPLE}ROOT${NC}"
    else
        echo -e "Mode       : ${CYAN}Normal User${NC}"
    fi

    if has_storage; then
        echo -e "Storage    : ${GREEN}● Available${NC}"
    else
        echo -e "Storage    : ${YELLOW}● Not Setup${NC}"
    fi
    echo ""
}

show_active_domains() {
    echo -e "${CYAN}=== Active Public URLs ===${NC}"
    
    if [ -f $LOG_DIR/ngrok.log ]; then
        url=$(grep -o 'https://[a-zA-Z0-9-]*\.ngrok.io' $LOG_DIR/ngrok.log | tail -1)
        [ ! -z "$url" ] && echo -e "Ngrok      : ${GREEN}$url${NC}"
    fi

    if [ -f $LOG_DIR/cloudflare.log ]; then
        url=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare.com' $LOG_DIR/cloudflare.log | tail -1)
        [ ! -z "$url" ] && echo -e "Cloudflare : ${GREEN}$url${NC}"
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
        echo -e "  ${PURPLE}10) Termux:Boot Setup (Choose Services)${NC}"
        echo -e "  ${PURPLE}11) Advanced Root Options${NC}"
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
    ls "$SITES_DIR" 2>/dev/null | while read s; do
        echo "  → $s → http://$s.localhost:8080"
    done
}

start_services() {
    pkill nginx php-fpm mysqld 2>/dev/null || true
    php-fpm && nginx
    echo -e "${GREEN}Services started.${NC}"
}

stop_services() {
    pkill nginx php-fpm mysqld 2>/dev/null || true
    echo -e "${RED}Services stopped.${NC}"
}

setup_tunnel() {
    echo "1) Ngrok  2) Cloudflare  3) localhost.run"
    read -p "Choose: " c
    case $c in
        1) read -p "Token: " t; ngrok config add-authtoken "$t"; ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 & ;;
        2) pkg install cloudflared -y; cloudflared tunnel --url http://localhost:8080 > $LOG_DIR/cloudflare.log 2>&1 & ;;
        3) ssh -R 80:localhost:8080 nokey@localhost.run > $LOG_DIR/localhostrun.log 2>&1 & ;;
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

# ==================== TERMUX BOOT v2.8 (Configurable) ====================
setup_termux_boot() {
    if ! is_root; then
        echo -e "${RED}This feature is only for ROOT users.${NC}"
        return
    fi

    echo -e "${PURPLE}=== Termux:Boot Configuration ===${NC}"
    echo "Choose which services to start automatically on device boot:"
    echo ""

    read -p "Start Nginx? (y/n): " start_nginx
    read -p "Start PHP-FPM? (y/n): " start_php
    read -p "Start MariaDB? (y/n): " start_mariadb
    read -p "Start Ngrok Tunnel? (y/n): " start_ngrok
    read -p "Start Cloudflare Tunnel? (y/n): " start_cloudflare

    mkdir -p "$BOOT_DIR"

    cat > "$BOOT_DIR/start-termhost.sh" << BOOTEOF
#!/data/data/com.termux/files/usr/bin/bash

# TermHost Auto Start - Generated by TermHost v2.8
sleep 12

pkill nginx 2>/dev/null || true
pkill php-fpm 2>/dev/null || true
pkill mysqld 2>/dev/null || true

BOOTEOF

    # Add selected services
    if [[ "$start_nginx" == "y" || "$start_nginx" == "Y" ]]; then
        echo "nginx >/dev/null 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"
    fi

    if [[ "$start_php" == "y" || "$start_php" == "Y" ]]; then
        echo "php-fpm >/dev/null 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"
    fi

    if [[ "$start_mariadb" == "y" || "$start_mariadb" == "Y" ]]; then
        echo "mysqld_safe --datadir=\u0024PREFIX/var/lib/mysql >/dev/null 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"
    fi

    if [[ "$start_ngrok" == "y" || "$start_ngrok" == "Y" ]]; then
        echo "ngrok http 8080 > \u0024HOME/termhost/logs/ngrok.log 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"
    fi

    if [[ "$start_cloudflare" == "y" || "$start_cloudflare" == "Y" ]]; then
        echo "cloudflared tunnel --url http://localhost:8080 > \u0024HOME/termhost/logs/cloudflare.log 2>&1 &" >> "$BOOT_DIR/start-termhost.sh"
    fi

    chmod +x "$BOOT_DIR/start-termhost.sh"

    echo -e "${GREEN}Termux:Boot script created successfully!${NC}"
    echo ""
    echo -e "${CYAN}Selected Services:${NC}"
    [[ "$start_nginx" == "y" || "$start_nginx" == "Y" ]] && echo "  - Nginx"
    [[ "$start_php" == "y" || "$start_php" == "Y" ]] && echo "  - PHP-FPM"
    [[ "$start_mariadb" == "y" || "$start_mariadb" == "Y" ]] && echo "  - MariaDB"
    [[ "$start_ngrok" == "y" || "$start_ngrok" == "Y" ]] && echo "  - Ngrok"
    [[ "$start_cloudflare" == "y" || "$start_cloudflare" == "Y" ]] && echo "  - Cloudflare Tunnel"
    echo ""
    echo -e "${YELLOW}Don't forget to install Termux:Boot app from F-Droid if you haven't.${NC}"
}

install_termux_boot_app() {
    if ! is_root; then
        echo -e "${RED}Root required.${NC}"
        return
    fi

    echo -e "${YELLOW}For best compatibility, install Termux:Boot from F-Droid manually.${NC}"
    echo ""
    read -p "Create boot script anyway? (y/n): " ans
    if [[ "$ans" == "y" || "$ans" == "Y" ]]; then
        setup_termux_boot
    fi
}

root_boot_menu() {
    if ! is_root; then
        echo -e "${RED}Root access required.${NC}"
        return
    fi

    echo -e "${PURPLE}=== Termux:Boot (Auto Start on Boot) ===${NC}"
    echo "1) Configure & Setup Termux:Boot (Choose Services)"
    echo "2) Help Install Termux:Boot App"
    echo "3) Back"
    read -p "Choose: " c

    case $c in
        1) setup_termux_boot ;;
        2) install_termux_boot_app ;;
        *)
            return
            ;;
    esac
}

# ==================== END TERMUX BOOT ====================

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
                    echo "Advanced root options..."
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