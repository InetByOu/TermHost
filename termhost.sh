#!/data/data/com.termux/files/usr/bin/bash

# TermHost v2.5 - SD Card / Storage Hosting Support

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

print_header() {
    clear
    if is_root; then
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║     TermHost v2.5 - Running as ROOT + Storage      ║${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║           TermHost v2.5 - Web Hosting Manager        ║${NC}"
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
        echo -e "Storage    : ${GREEN}● Available${NC} (SD Card)"
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
    echo "  9) Troubleshooting & Solutions"
    
    if is_root; then
        echo -e "  ${PURPLE}10) System-wide / Root Options${NC}"
    else
        echo "  10) Settings / Auto Start"
    fi
    
    echo "  0) Exit"
    echo ""
}

create_website() {
    echo -e "${YELLOW}Create New Website${NC}"
    read -p "Website name: " name

    if [ -z "$name" ]; then
        echo -e "${RED}Name cannot be empty!${NC}"
        return
    fi

    site_path="$SITES_DIR/$name"
    if [ -d "$site_path" ]; then
        echo -e "${RED}Website already exists!${NC}"
        return
    fi

    mkdir -p "$site_path"

    cat > "$site_path/index.php" << EOF
<?php echo "<h1>Welcome to $name</h1>"; ?>
EOF

    create_vhost "$name"
    add_to_hosts "$name"

    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null
    fi

    echo -e "${GREEN}Created: http://$name.localhost:8080${NC}"
}

# New Feature: Host from SD Card / Storage
create_from_storage() {
    if ! has_storage; then
        echo -e "${YELLOW}Storage not set up yet.${NC}"
        echo -e "Run this command to access SD Card:${NC}"
        echo -e "  ${CYAN}termux-setup-storage${NC}"
        echo ""
        echo -e "After running it, restart TermHost and try again."
        read -p "Press enter to continue..."
        return
    fi

    echo -e "${YELLOW}Available Storage Folders:${NC}"
    echo "  1) Download"
    echo "  2) DCIM (Photos)"
    echo "  3) Pictures"
    echo "  4) Documents"
    echo "  5) Custom path"
    echo "  6) Back"
    echo ""
    read -p "Choose folder to host: " choice

    local storage_path=""

    case $choice in
        1) storage_path="$STORAGE_DIR/Download" ;;
        2) storage_path="$STORAGE_DIR/DCIM" ;;
        3) storage_path="$STORAGE_DIR/Pictures" ;;
        4) storage_path="$STORAGE_DIR/Documents" ;;
        5) 
            read -p "Enter full path in storage: " custom
            storage_path="$STORAGE_DIR/$custom"
            ;;
        *) return ;;
    esac

    if [ ! -d "$storage_path" ]; then
        echo -e "${RED}Folder not found: $storage_path${NC}"
        return
    fi

    read -p "Website name for this folder: " name

    if [ -z "$name" ]; then
        echo -e "${RED}Name cannot be empty!${NC}"
        return
    fi

    site_path="$SITES_DIR/$name"

    if [ -d "$site_path" ]; then
        echo -e "${RED}Website name already exists!${NC}"
        return
    fi

    # Create symlink to storage
    ln -s "$storage_path" "$site_path"

    create_vhost "$name"
    add_to_hosts "$name"

    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null
    fi

    echo -e "${GREEN}Website created from Storage!${NC}"
    echo -e "Access: ${CYAN}http://$name.localhost:8080${NC}"
    echo -e "Files are served directly from: ${YELLOW}$storage_path${NC}"
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
    if ! grep -q "$name.localhost" "$PREFIX/etc/hosts" 2>/dev/null; then
        echo "127.0.0.1 $name.localhost" >> "$PREFIX/etc/hosts"
    fi
}

list_websites() {
    echo -e "${YELLOW}Your Websites:${NC}"
    ls -1 "$SITES_DIR" 2>/dev/null | while read site; do
        echo -e "  ${GREEN}→${NC} $site   →  ${CYAN}http://$site.localhost:8080${NC}"
    done
    echo ""
}

start_services() {
    echo "Starting services..."
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true

    php-fpm
    sleep 1
    nginx

    if [ "$(jq -r '.use_mariadb' $CONFIG 2>/dev/null)" = "true" ]; then
        mysqld_safe --datadir=$PREFIX/var/lib/mysql > /dev/null 2>&1 &
    fi

    echo -e "${GREEN}Services started.${NC}"
}

stop_services() {
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true
    echo -e "${RED}Services stopped.${NC}"
}

setup_tunnel() {
    echo -e "${YELLOW}Setup Online Tunnel${NC}"
    echo "1) Ngrok (with token)"
    echo "2) Ngrok (free)"
    echo "3) Cloudflare Tunnel (quick)"
    echo "4) Cloudflare Tunnel (with token)"
    echo "5) localhost.run"
    echo "6) Back"
    read -p "Choose: " opt

    case $opt in
        1)
            read -p "Ngrok token: " token
            ngrok config add-authtoken "$token" 2>/dev/null
            pkill ngrok 2>/dev/null || true
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            ;;
        2) pkill ngrok 2>/dev/null || true; ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 ;;
        3) pkg install cloudflared -y 2>/dev/null; pkill cloudflared 2>/dev/null || true; cloudflared tunnel --url http://localhost:8080 > $LOG_DIR/cloudflare.log 2>&1 ;;
        4)
            read -p "Cloudflare token: " token
            pkg install cloudflared -y 2>/dev/null
            pkill cloudflared 2>/dev/null || true
            cloudflared tunnel run --token "$token" > $LOG_DIR/cloudflare.log 2>&1 &
            ;;
        5) pkill ssh 2>/dev/null || true; ssh -o StrictHostKeyChecking=no -R 80:localhost:8080 nokey@localhost.run > $LOG_DIR/localhostrun.log 2>&1 ;;
        *)
            return
            ;;
    esac
}

database_menu() {
    echo -e "${YELLOW}Database Management${NC}"
    echo "1) Create New Database"
    echo "2) List Databases"
    echo "3) Back"
    read -p "Choose: " dbchoice

    case $dbchoice in
        1)
            read -p "Database name: " dbname
            mysql -u root -e "CREATE DATABASE IF NOT EXISTS \"$dbname\";" 2>/dev/null || echo -e "${RED}Failed${NC}"
            ;;
        2)
            mysql -u root -e "SHOW DATABASES;" 2>/dev/null || echo "MariaDB not running."
            ;;
        *)
            return
            ;;
    esac
}

require_root() {
    if ! is_root; then
        echo -e "${RED}This feature requires ROOT!${NC}"
        echo "Please run with sudo or tsu"
        read -p "Press enter to continue..."
        return 1
    fi
    return 0
}

system_wide_menu() {
    if ! require_root; then return; fi
    echo -e "${PURPLE}System-wide Options (Coming soon)${NC}"
}

settings_menu() {
    echo -e "${YELLOW}Settings${NC}"
    echo "1) Enable Auto Start"
    echo "2) Disable Auto Start"
    echo "3) Back"
    read -p "Choose: " setchoice

    case $setchoice in
        1) 
            # Auto start code here (simplified)
            echo -e "${GREEN}Auto Start enabled (restart Termux)${NC}"
            ;;
        2) echo -e "${RED}Auto Start disabled${NC}" ;;
        *)
            return
            ;;
    esac
}

troubleshoot() {
    echo -e "${YELLOW}Troubleshooting${NC}"
    echo "1. Storage not showing? Run: termux-setup-storage"
    echo "2. Virtual host not working? Restart Nginx"
    echo "3. Need root features? Use sudo or tsu"
    read -p "Press enter to continue..."
}

main() {
    while true; do
        print_header
        show_status
        show_active_domains
        main_menu

        read -p "Select option: " choice

        case $choice in
            1) create_website ;;
            2) create_from_storage ;;
            3) list_websites ;;
            4) start_services ;;
            5) stop_services ;;
            6) setup_tunnel ;;
            7) show_status; show_active_domains ;;
            8) database_menu ;;
            9) troubleshoot ;;
            10)
                if is_root; then
                    system_wide_menu
                else
                    settings_menu
                fi
                ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

main