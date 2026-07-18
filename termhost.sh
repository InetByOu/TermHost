#!/data/data/com.termux/files/usr/bin/bash

# TermHost v2 - Full Interactive CLI

CONFIG="$HOME/termhost/config/config.json"
SITES_DIR="$HOME/termhost/sites"
LOG_DIR="$HOME/termhost/logs"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     TermHost v2 - Web Hosting Manager      ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
}

show_status() {
    echo -e "${CYAN}=== Service Status ===${NC}"
    
    if pgrep -x nginx >/dev/null; then
        echo -e "Nginx      : ${GREEN}● Running${NC} (Port 8080)"
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

    # Check active tunnels
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
        url=$(grep -o 'https://[a-zA-Z0-9]*\.ngrok.io' $LOG_DIR/ngrok.log | tail -1)
        if [ ! -z "$url" ]; then
            echo -e "Ngrok      : ${GREEN}$url${NC}"
        fi
    fi

    if [ -f $LOG_DIR/cloudflare.log ]; then
        url=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare.com' $LOG_DIR/cloudflare.log | tail -1)
        if [ ! -z "$url" ]; then
            echo -e "Cloudflare : ${GREEN}$url${NC}"
        fi
    fi
    echo ""
}

main_menu() {
    echo -e "${YELLOW}Main Menu:${NC}"
    echo "  1)  Create New Website"
    echo "  2)  List All Websites"
    echo "  3)  Start All Services"
    echo "  4)  Stop All Services"
    echo "  5)  Setup Online Tunnel"
    echo "  6)  View Full Status & Active Domains"
    echo "  7)  Database Management"
    echo "  8)  Troubleshooting & Solutions"
    echo "  9)  Settings"
    echo "  0)  Exit"
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
    mkdir -p "$site_path"

    cat > "$site_path/index.php" << 'EOF'
<?php
    echo "<h1>Welcome to $name</h1>";
    echo "<p>TermHost is running successfully!</p>";
?>
EOF

    echo -e "${GREEN}Website created successfully!${NC}"
    echo -e "Location: ${CYAN}$site_path${NC}"
}

list_websites() {
    echo -e "${YELLOW}Available Websites:${NC}"
    ls -1 $SITES_DIR 2>/dev/null || echo "No websites found."
    echo ""
}

start_services() {
    echo -e "Starting services..."
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true

    php-fpm
    nginx

    if [ "$(jq -r '.use_mariadb' $CONFIG)" = "true" ]; then
        mysqld_safe --datadir=$PREFIX/var/lib/mysql > /dev/null 2>&1 &
    fi

    echo -e "${GREEN}All services started!${NC}"
}

stop_services() {
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true
    echo -e "${RED}All services stopped.${NC}"
}

setup_tunnel() {
    echo -e "${YELLOW}Setup Online Tunnel${NC}"
    echo "1) Ngrok (Recommended - with token)"
    echo "2) Ngrok (Free - without token)"
    echo "3) Cloudflare Tunnel (Free + Custom Domain)"
    echo "4) localhost.run (Quick)"
    echo "5) Back"
    read -p "Choose: " opt

    case $opt in
        1)
            read -p "Ngrok Authtoken: " token
            jq ".ngrok_token = \"$token\"" $CONFIG > tmp.json && mv tmp.json $CONFIG
            ngrok config add-authtoken $token
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            echo -e "${GREEN}Ngrok started with token!${NC}"
            ;;
        2)
            ngrok http 8080 > $LOG_DIR/ngrok.log 2>&1 &
            echo -e "${YELLOW}Ngrok started (free tier)${NC}"
            ;;
        3)
            echo "Installing cloudflared..."
            pkg install cloudflared -y
            read -p "Cloudflare Tunnel Token (leave empty for quick tunnel): " cftoken
            if [ -z "$cftoken" ]; then
                cloudflared tunnel --url http://localhost:8080 > $LOG_DIR/cloudflare.log 2>&1 &
            else
                cloudflared tunnel run --token $cftoken > $LOG_DIR/cloudflare.log 2>&1 &
            fi
            echo -e "${GREEN}Cloudflare Tunnel started!${NC}"
            ;;
        4)
            echo "Starting localhost.run..."
            ssh -R 80:localhost:8080 nokey@localhost.run > $LOG_DIR/localhostrun.log 2>&1 &
            ;;
        *)
            return
            ;;
    esac
}

troubleshoot() {
    echo -e "${YELLOW}Common Issues & Solutions${NC}"
    echo ""
    echo "1. Port 8080 already in use"
    echo "   Solution: pkill nginx && pkill php-fpm"
    echo ""
    echo "2. PHP files not executing"
    echo "   Solution: Make sure php-fpm is running"
    echo ""
    echo "3. Permission denied when accessing site"
    echo "   Solution: chmod -R 755 ~/termhost/sites"
    echo ""
    echo "4. MariaDB won't start"
    echo "   Solution: Run 'mariadb-install-db --user=$(whoami)'"
    echo ""
    echo "5. Ngrok shows 'command not found'"
    echo "   Solution: pkg install ngrok"
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
            7) echo "Database management coming in next update..." ;;
            8) troubleshoot ;;
            9) echo "Settings menu coming soon..." ;;
            0) echo "Exiting TermHost..."; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

main