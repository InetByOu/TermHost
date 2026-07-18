#!/data/data/com.termux/files/usr/bin/bash

# TermHost v4.6 - Real-time Dashboard

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

is_root() { [ "$(id -u)" -eq 0 ]; }
has_storage() { [ -d "$STORAGE_DIR" ]; }
get_port() { jq -r '.port // 8080' "$CONFIG" 2>/dev/null || echo 8080; }

handle_error() {
    echo -e "${RED}[Error]${NC} $1"
    sleep 1.5
}

print_header() {
    if is_root; then
        echo -e "${PURPLE}TermHost v4.6${NC} - Root Mode | Port: $(get_port)"
    else
        echo -e "${BLUE}TermHost v4.6${NC} | Port: $(get_port)"
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
}

show_menu() {
    echo -e "${YELLOW}Main Menu:${NC}"
    echo "  1) Create Website          6) Setup Tunnel"
    echo "  2) Create from Storage     7) Refresh Status"
    echo "  3) List Websites           8) Database"
    echo "  4) Start Services          9) Fix Permissions"
    echo "  5) Stop Services          10) Change Port"
    
    if is_root; then
        echo -e "  ${PURPLE}11) Termux:Boot${NC}          ${PURPLE}12) Swap Management${NC}"
    fi
    
    echo "  0) Exit"
    echo ""
    echo -e "${CYAN}Press number to choose, or wait to refresh...${NC}"
}

show_dashboard() {
    while true; do
        clear
        print_header
        show_status
        show_active_domains
        show_menu

        # Wait for input with timeout (real-time feel)
        if read -t 4 -n 1 choice; then
            case $choice in
                1) create_website; return ;;
                2) create_from_storage; return ;;
                3) list_websites; return ;;
                4) start_services; return ;;
                5) stop_services; return ;;
                6) setup_tunnel; return ;;
                7) ;; # just refresh
                8) database_menu; return ;;
                9) fix_permissions; return ;;
                0) echo "Goodbye!"; exit 0 ;;
                *) ;; # invalid, refresh
            esac
        fi
    done
}

change_port() {
    local current_port=$(get_port)
    echo -e "${YELLOW}Current Port: $current_port${NC}"
    read -p "New port: " new_port

    if ! [[ "$new_port" =~ ^[0-9]+$ ]]; then
        handle_error "Invalid port"
        return
    fi

    jq ".port = $new_port" "$CONFIG" > tmp.json && mv tmp.json "$CONFIG" 2>/dev/null || echo "{ \"port\": $new_port }" > "$CONFIG"
    sed -i "s/listen .*;/listen       $new_port;/" $PREFIX/etc/nginx/nginx.conf

    if pgrep nginx >/dev/null; then
        nginx -s reload 2>/dev/null || true
    fi

    echo -e "${GREEN}Port changed to $new_port${NC}"
}

create_website() { ... }   # (keep previous functions)
create_from_storage() { ... }
create_vhost() { ... }
add_to_hosts() { ... }
list_websites() { ... }
start_services() { ... }
stop_services() { ... }
setup_tunnel() { ... }
database_menu() { ... }
fix_permissions() { ... }

main() {
    while true; do
        show_dashboard
    done
}

main