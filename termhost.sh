#!/data/data/com.termux/files/usr/bin/bash

# TermHost v2.2 - With Proper Virtual Hosts

CONFIG="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"
VHOST_DIR="$HOME/termhost/vhosts"
NGINX_CONF="$PREFIX/etc/nginx/nginx.conf"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         TermHost v2.2 - Virtual Host Support           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_status() {
    echo -e "${CYAN}=== Service Status ===${NC}"
    
    if pgrep -x nginx >/dev/null; then
        echo -e "Nginx      : ${GREEN}● Running${NC} (Virtual Hosts Enabled)"
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

    if pgrep -x ngrok >/dev/null; then
        echo -e "Ngrok      : ${GREEN}● Running${NC}"
    fi
    if pgrep -x cloudflared >/dev/null; then
        echo -e "Cloudflare : ${GREEN}● Running${NC}"
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
    echo "  9) Settings"
    echo "  0) Exit"
    echo ""
}

# Create Nginx Virtual Host config
create_vhost() {
    local name=$1
    local vhost_file="$VHOST_DIR/$name.conf"

    mkdir -p "$VHOST_DIR"

    cat > "$vhost_file" << EOF
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

    echo -e "${GREEN}Virtual host created for $name.localhost${NC}"
}

# Add domain to Termux hosts file
add_to_hosts() {
    local name=$1
    local hosts_file="$PREFIX/etc/hosts"

    if ! grep -q "$name.localhost" "$hosts_file" 2>/dev/null; then
        echo "127.0.0.1 $name.localhost" >> "$hosts_file"
        echo -e "${GREEN}Added $name.localhost to hosts file${NC}"
    fi
}

create_website() {
    echo -e "${YELLOW}Create New Website with Virtual Host${NC}"
    read -p "Website name (example: mysite): " name

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

    # Create sample index.php
    cat > "$site_path/index.php" << EOF
<?php
    echo "<h1>Welcome to $name</h1>";
    echo "<p>TermHost Virtual Host is working!</p>";
?>
EOF

    # Create virtual host config
    create_vhost "$name"

    # Add to hosts file
    add_to_hosts "$name"

    # Reload nginx config
    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null || echo -e "${YELLOW}Please restart Nginx to apply changes.${NC}"
    fi

    echo -e "${GREEN}Website created successfully!${NC}"
    echo -e "Access it at: ${CYAN}http://$name.localhost:8080${NC}"
}

list_websites() {
    echo -e "${YELLOW}Your Websites (Virtual Hosts):${NC}"
    if [ -d "$SITES_DIR" ]; then
        ls -1 "$SITES_DIR" | while read site; do
            echo -e "  ${GREEN}→${NC} $site   →  ${CYAN}http://$site.localhost:8080${NC}"
        done
    else
        echo "No websites found."
    fi
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

    echo -e "${GREEN}All services started successfully!${NC}"
}

stop_services() {
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true
    echo -e "${RED}All services stopped.${NC}"
}

setup_tunnel() {
    echo -e "${YELLOW}Setup Online Public Access${NC}"
    echo ""
    echo "1) Ngrok (with your token) - Recommended"
    echo "2) Ngrok (free without token)"
    echo "3) Cloudflare Tunnel (quick free)"
    echo "4) Cloudflare Tunnel (with token)"
    echo "5) localhost.run"
    echo "6) Back"
    echo ""
    read -p "Choose option: " opt

    case $opt in
        1)
            read -p "Ngrok Authtoken: " token
            ngrok config add-authtoken "$token" 2>/dev/null
            pkill ngrok 2>/dev/null || true
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            echo -e "${GREEN}Ngrok started!${NC}"
            ;;
        2)
            pkill ngrok 2>/dev/null || true
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            echo -e "${YELLOW}Ngrok started (free)${NC}"
            ;;
        3)
            pkg install cloudflared -y 2>/dev/null
            pkill cloudflared 2>/dev/null || true
            cloudflared tunnel --url http://localhost:8080 > $LOG_DIR/cloudflare.log 2>&1 &
            echo -e "${GREEN}Cloudflare quick tunnel started!${NC}"
            ;;
        4)
            read -p "Cloudflare Tunnel Token: " token
            pkg install cloudflared -y 2>/dev/null
            pkill cloudflared 2>/dev/null || true
            cloudflared tunnel run --token "$token" > $LOG_DIR/cloudflare.log 2>&1 &
            echo -e "${GREEN}Cloudflare Tunnel started!${NC}"
            ;;
        5)
            pkill ssh 2>/dev/null || true
            ssh -o StrictHostKeyChecking=no -R 80:localhost:8080 nokey@localhost.run > $LOG_DIR/localhostrun.log 2>&1 &
            echo -e "${GREEN}localhost.run started!${NC}"
            ;;
        *)
            return
            ;;
    esac
}

database_menu() {
    echo -e "${YELLOW}Database Management${NC}"
    echo "1) Create New Database"
    echo "2) List All Databases"
    echo "3) Back"
    read -p "Choose: " dbchoice

    case $dbchoice in
        1)
            read -p "Database name: " dbname
            mysql -u root -e "CREATE DATABASE IF NOT EXISTS \"$dbname\";" 2>/dev/null || echo -e "${RED}Failed. Is MariaDB running?${NC}"
            echo -e "${GREEN}Database created successfully.${NC}"
            ;;
        2)
            echo -e "${CYAN}Available Databases:${NC}"
            mysql -u root -e "SHOW DATABASES;" 2>/dev/null || echo "MariaDB not running."
            ;;
        *)
            return
            ;;
    esac
}

troubleshoot() {
    echo -e "${YELLOW}Common Problems & Solutions${NC}"
    echo ""
    echo "${RED}1. Virtual host not working${NC}"
    echo "   → Make sure you restarted Nginx after creating site"
    echo "   → Try accessing: http://namawebsite.localhost:8080"
    echo ""
    echo "${RED}2. PHP not working${NC}"
    echo "   → Restart PHP-FPM and Nginx"
    echo ""
    echo "${RED}3. Permission denied${NC}"
    echo "   → chmod -R 755 ~/termhost/sites"
    echo ""
    echo "${RED}4. MariaDB error${NC}"
    echo "   → Run: mariadb-install-db --user=$(whoami)"
    echo ""
    read -p "Press enter to continue..."
}

main() {
    while true; do
        print_header
        show_status
        show_active_domains
        main_menu

        read -p "Select option [0-9]: " choice

        case $choice in
            1) create_website ;;
            2) list_websites ;;
            3) start_services ;;
            4) stop_services ;;
            5) setup_tunnel ;;
            6) show_status; show_active_domains ;;
            7) database_menu ;;
            8) troubleshoot ;;
            9) echo "Settings coming in next update" ;;
            0) echo "Thank you for using TermHost!"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

main