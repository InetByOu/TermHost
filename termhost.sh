#!/data/data/com.termux/files/usr/bin/bash

# TermHost - Termux Web Hosting Manager
# Interactive CLI

CONFIG_FILE="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    clear
    echo -e "${BLUE}====================================${NC}"
    echo -e "${BLUE}   TermHost - Web Hosting Manager${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
}

show_status() {
    echo -e "${YELLOW}=== Current Status ===${NC}"
    
    # Check Nginx
    if pgrep -x "nginx" > /dev/null; then
        echo -e "Nginx          : ${GREEN}Running${NC}"
    else
        echo -e "Nginx          : ${RED}Stopped${NC}"
    fi

    # Check PHP-FPM
    if pgrep -x "php-fpm" > /dev/null; then
        echo -e "PHP-FPM        : ${GREEN}Running${NC}"
    else
        echo -e "PHP-FPM        : ${RED}Stopped${NC}"
    fi

    # Check MariaDB
    if pgrep -x "mysqld" > /dev/null; then
        echo -e "MariaDB        : ${GREEN}Running${NC}"
    else
        echo -e "MariaDB        : ${RED}Stopped${NC}"
    fi

    echo ""
}

show_menu() {
    echo "1) Install / Repair Environment"
    echo "2) Create New Website"
    echo "3) Start All Services"
    echo "4) Stop All Services"
    echo "5) Setup Online Tunnel (Ngrok / Cloudflare)"
    echo "6) View Active Domains & Status"
    echo "7) Troubleshooting & Solutions"
    echo "8) Settings"
    echo "0) Exit"
    echo ""
}

create_website() {
    echo -e "${YELLOW}Create New Website${NC}"
    read -p "Website name (folder): " site_name

    if [ -z "$site_name" ]; then
        echo "Website name cannot be empty!"
        return
    fi

    site_path="$SITES_DIR/$site_name"
    mkdir -p "$site_path"

    # Create sample index.php
    cat > "$site_path/index.php" << 'EOF'
<?php
phpinfo();
EOF

    echo -e "${GREEN}Website created at: $site_path${NC}"
    echo "You can edit files in that folder."
}

setup_tunnel() {
    echo -e "${YELLOW}Setup Online Tunnel${NC}"
    echo "1) Ngrok (with token)"
    echo "2) Ngrok (without token - limited)"
    echo "3) Cloudflare Tunnel"
    echo "4) Back"
    read -p "Choose option: " tunnel_choice

    case $tunnel_choice in
        1)
            read -p "Enter your Ngrok authtoken: " token
            ngrok config add-authtoken $token
            echo "Starting Ngrok..."
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            echo -e "${GREEN}Ngrok started! Check your dashboard or log.${NC}"
            ;;
        2)
            echo "Starting Ngrok without token..."
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            ;;
        3)
            echo "Cloudflare Tunnel setup coming soon..."
            ;;
        *)
            return
            ;;
    esac
}

troubleshooting() {
    echo -e "${YELLOW}Common Problems & Solutions${NC}"
    echo ""
    echo "1. Port 8080 already in use"
    echo "   -> pkill nginx && pkill php-fpm"
    echo ""
    echo "2. PHP not working"
    echo "   -> Check php-fpm is running"
    echo ""
    echo "3. Permission denied"
    echo "   -> chmod -R 755 ~/termhost/sites"
    echo ""
    echo "4. MariaDB cannot start"
    echo "   -> mariadb-install-db --user=$(whoami)"
    echo ""
    read -p "Press enter to continue..."
}

main() {
    while true; do
        print_header
        show_status
        show_menu

        read -p "Choose option: " choice

        case $choice in
            1) bash ~/termhost/install.sh ;;
            2) create_website ;;
            3) 
                pkill nginx || true
                pkill php-fpm || true
                php-fpm &
                nginx
                echo -e "${GREEN}Services started!${NC}"
                ;;
            4)
                pkill nginx || true
                pkill php-fpm || true
                echo -e "${RED}Services stopped.${NC}"
                ;;
            5) setup_tunnel ;;
            6) show_status ;;
            7) troubleshooting ;;
            8) echo "Settings menu coming soon..." ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid option" ;;
        esac

        echo ""
        read -p "Press enter to continue..."
    done
}

main