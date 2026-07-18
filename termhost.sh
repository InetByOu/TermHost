#!/data/data/com.termux/files/usr/bin/bash

# TermHost v2.4 - Root Support + Extra Options for Root Users

CONFIG="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"
VHOST_DIR="$HOME/termhost/vhosts"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Root Detection
is_root() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

print_header() {
    clear
    if is_root; then
        echo -e "${PURPLE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${PURPLE}║     TermHost v2.4 - Running as ROOT                  ║${NC}"
        echo -e "${PURPLE}╚════════════════════════════════════════════════════════╝${NC}"
    else
        echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║           TermHost v2.4 - Web Hosting Manager        ║${NC}"
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
    echo "  2) List All Websites"
    echo "  3) Start All Services"
    echo "  4) Stop All Services"
    echo "  5) Setup Online Tunnel"
    echo "  6) View Status & Active Public URLs"
    echo "  7) Database Management"
    echo "  8) Troubleshooting & Solutions"
    
    if is_root; then
        echo -e "  ${PURPLE}9) System-wide Install / Manage${NC}"
        echo -e "  ${PURPLE}10) Advanced Root Options${NC}"
    else
        echo "  9) Settings / Auto Start"
    fi
    
    echo "  0) Exit"
    echo ""
}

create_website() {
    echo -e "${YELLOW}Create New Website with Virtual Host${NC}"
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
<?php
    echo "<h1>Welcome to $name</h1>";
    echo "<p>TermHost is working!</p>";
?>
EOF

    create_vhost "$name"
    add_to_hosts "$name"

    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null
    fi

    echo -e "${GREEN}Website created: ${CYAN}http://$name.localhost:8080${NC}"
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

# Root Only Functions
require_root() {
    if ! is_root; then
        echo -e "${RED}This feature requires ROOT access!${NC}"
        echo -e "Please run with: ${YELLOW}sudo termhost${NC} or ${YELLOW}tsu${NC}"
        read -p "Press enter to continue..."
        return 1
    fi
    return 0
}

system_wide_menu() {
    if ! require_root; then return; fi

    echo -e "${PURPLE}=== System-wide / Root Options ===${NC}"
    echo "1) Install Nginx/PHP system-wide"
    echo "2) Manage System Services (systemd)"
    echo "3) Change Web Root to /var/www"
    echo "4) Back"
    read -p "Choose: " choice

    case $choice in
        1) echo "System-wide installation coming soon..." ;;
        2) echo "System service management coming soon..." ;;
        3) echo "Changing web root..." ;;
        *)
            return
            ;;
    esac
}

advanced_root_options() {
    if ! require_root; then return; fi

    echo -e "${PURPLE}=== Advanced Root Options ===${NC}"
    echo "1) Full System Update & Optimize"
    echo "2) Install Additional Services (Redis, etc)"
    echo "3) Security Hardening"
    echo "4) Back"
    read -p "Choose: " choice

    case $choice in
        1) echo "Running system optimization..." ;;
        2) echo "Additional services coming soon..." ;;
        3) echo "Security features coming soon..." ;;
        *)
            return
            ;;
    esac
}

enable_autostart() {
    local bashrc="$HOME/.bashrc"
    if grep -q "TERMHOST_AUTO_START" "$bashrc" 2>/dev/null; then
        echo -e "${YELLOW}Auto Start already enabled.${NC}"
        return
    fi

    cat >> "$bashrc" << 'EOF'
# TERMHOST_AUTO_START
if ! pgrep -x nginx >/dev/null; then
    php-fpm >/dev/null 2>&1
    nginx >/dev/null 2>&1
fi
EOF
    echo -e "${GREEN}Auto Start enabled.${NC}"
}

disable_autostart() {
    sed -i '/TERMHOST_AUTO_START/,+5d' "$HOME/.bashrc" 2>/dev/null
    echo -e "${RED}Auto Start disabled.${NC}"
}

settings_menu() {
    echo -e "${YELLOW}Settings${NC}"
    echo "1) Enable Auto Start"
    echo "2) Disable Auto Start"
    echo "3) Back"
    read -p "Choose: " setchoice

    case $setchoice in
        1) enable_autostart ;;
        2) disable_autostart ;;
        *)
            return
            ;;
    esac
}

troubleshoot() {
    echo -e "${YELLOW}Common Problems & Solutions${NC}"
    echo "1. Virtual host not working"
    echo "   → Restart Nginx"
    echo "2. Need root features"
    echo "   → Run with sudo or tsu"
    echo "3. Permission issues"
    echo "   → chmod -R 755 sites/"
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
            2) list_websites ;;
            3) start_services ;;
            4) stop_services ;;
            5) setup_tunnel ;;
            6) show_status; show_active_domains ;;
            7) database_menu ;;
            8) troubleshoot ;;
            9)
                if is_root; then
                    system_wide_menu
                else
                    settings_menu
                fi
                ;;
            10)
                if is_root; then
                    advanced_root_options
                else
                    echo -e "${RED}Invalid option${NC}"
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