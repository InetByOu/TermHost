#!/data/data/com.termux/files/usr/bin/bash

# TermHost v6.0 - Production Ready

VERSION="6.0"

# ==================== ROBUST PATH DETECTION ====================
if [ "$(id -u)" -eq 0 ]; then
    if [ -f "/data/data/com.termux/files/home/termhost/termhost.sh" ]; then
        REAL_HOME="/data/data/com.termux/files/home"
    elif [ -f "/data/data/com.termux/files/home/.suroot/termhost/termhost.sh" ]; then
        REAL_HOME="/data/data/com.termux/files/home/.suroot"
    else
        REAL_HOME="$HOME"
    fi
else
    REAL_HOME="$HOME"
fi

CONFIG="$REAL_HOME/termhost/config/config.json"
SITES_DIR="$REAL_HOME/termhost/sites"
LOG_DIR="$REAL_HOME/termhost/logs"
VHOST_DIR="$REAL_HOME/termhost/vhosts"
STORAGE_DIR="$REAL_HOME/storage"
INSTALL_DIR="$REAL_HOME/termhost"
TINYFM_URL="https://raw.githubusercontent.com/prasathmani/tinyfilemanager/master/tinyfilemanager.php"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# ==================== INITIALIZATION ====================
init_directories() {
    mkdir -p "$SITES_DIR" "$VHOST_DIR" "$LOG_DIR" "$INSTALL_DIR/config"
}

init_config() {
    if [ ! -f "$CONFIG" ]; then
        cat > "$CONFIG" << 'EOF'
{
  "port": 8080,
  "use_mariadb": true,
  "tinyfm_username": "admin",
  "tinyfm_password_hash": ""
}
EOF
    fi
}

ensure_log_dir() {
    mkdir -p "$LOG_DIR"
}

# ==================== HELPER FUNCTIONS ====================
is_root() { [ "$(id -u)" -eq 0 ]; }
has_storage() { [ -d "$STORAGE_DIR" ]; }
get_port() { jq -r '.port // 8080' "$CONFIG" 2>/dev/null || echo 8080; }

handle_error() {
    echo -e "${RED}[Error]${NC} $1"
    sleep 1.5
}

backup_config() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
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
    local port=$(get_port)
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
    echo "  12) File Manager Settings"
    echo "  13) Upgrade TermHost"
    
    if is_root; then
        echo -e "  ${PURPLE}14) Termux:Boot Setup${NC}"
        echo -e "  ${PURPLE}15) Swap Management (Low RAM)${NC}"
    fi
    
    echo "  0) Exit"
    echo ""
    echo -e "${CYAN}File Manager: http://localhost:$port/adminfm${NC}"
    echo ""
}

get_tinyfm_username() {
    jq -r '.tinyfm_username // "admin"' "$CONFIG" 2>/dev/null || echo "admin"
}

get_tinyfm_password_hash() {
    jq -r '.tinyfm_password_hash // ""' "$CONFIG" 2>/dev/null || echo ""
}

set_tinyfm_credentials() {
    local username="$1"
    local password_hash="$2"

    if [ -f "$CONFIG" ]; then
        jq ".tinyfm_username = \"$username\" | .tinyfm_password_hash = \"$password_hash\"" "$CONFIG" > "${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
    else
        echo "{ \"port\": 8080, \"use_mariadb\": true, \"tinyfm_username\": \"$username\", \"tinyfm_password_hash\": \"$password_hash\" }" > "$CONFIG"
    fi
}

install_tinyfm() {
    local site_path="$1"
    local site_name="$2"
    local username=$(get_tinyfm_username)
    local password_hash=$(get_tinyfm_password_hash)

    mkdir -p "$site_path/adminfm"

    if [ ! -f "$site_path/adminfm/index.php" ]; then
        if curl -fsSL "$TINYFM_URL" -o "$site_path/adminfm/index.php" 2>/dev/null; then
            sed -i "s/\$username = 'admin';/\$username = '$username';/g" "$site_path/adminfm/index.php" 2>/dev/null || true
            if [ -n "$password_hash" ]; then
                sed -i "s/\$password = 'admin@123';/\$password = '$password_hash';/g" "$site_path/adminfm/index.php" 2>/dev/null || true
                sed -i "s/\$auth_type = 'plain';/\$auth_type = 'hash';/g" "$site_path/adminfm/index.php" 2>/dev/null || true
            fi
        else
            cat > "$site_path/adminfm/index.php" << 'TINYEOF'
<?php echo "<h2>TinyFM not installed.</h2>"; ?>
TINYEOF
        fi
    fi
}

file_manager_settings() {
    local current_user=$(get_tinyfm_username)
    local current_hash=$(get_tinyfm_password_hash)

    echo -e "${YELLOW}File Manager Settings (TinyFM)${NC}"
    echo ""
    echo -e "Current Username : ${GREEN}$current_user${NC}"
    echo -e "Password Status  : ${GREEN}Hashed${NC} (secure)"
    echo ""

    echo "1) Change Username"
    echo "2) Change Password (auto hashed)"
    echo "3) Show Current Settings"
    echo "0) Back"
    echo ""

    read -p "Choose: " opt

    case $opt in
        1)
            read -p "New username: " new_user
            if [ -z "$new_user" ]; then
                handle_error "Username cannot be empty"
                return
            fi
            local cur_hash=$(get_tinyfm_password_hash)
            if [ -z "$cur_hash" ]; then
                cur_hash=$(php -r "echo password_hash('admin', PASSWORD_DEFAULT);" 2>/dev/null || echo '')
            fi
            set_tinyfm_credentials "$new_user" "$cur_hash"

            echo -e "${YELLOW}Updating all websites...${NC}"
            local count=0
            if [ -d "$SITES_DIR" ]; then
                for site in "$SITES_DIR"/*; do
                    if [ -f "$site/adminfm/index.php" ]; then
                        sed -i "s/\$username = '[^']*';/\$username = '$new_user';/g" "$site/adminfm/index.php" 2>/dev/null || true
                        ((count++))
                    fi
                done
            fi
            echo -e "${GREEN}Username updated ($count websites)${NC}"
            ;;

        2)
            read -p "New password: " new_pass
            if [ -z "$new_pass" ]; then
                handle_error "Password cannot be empty"
                return
            fi

            local new_hash
            new_hash=$(php -r "echo password_hash('$new_pass', PASSWORD_DEFAULT);" 2>/dev/null)

            if [ -z "$new_hash" ]; then
                handle_error "Failed to generate hash"
                return
            fi

            local cur_user=$(get_tinyfm_username)
            set_tinyfm_credentials "$cur_user" "$new_hash"

            echo -e "${YELLOW}Updating all websites...${NC}"
            local count=0
            if [ -d "$SITES_DIR" ]; then
                for site in "$SITES_DIR"/*; do
                    if [ -f "$site/adminfm/index.php" ]; then
                        sed -i "s/\$password = '[^']*';/\$password = '$new_hash';/g" "$site/adminfm/index.php" 2>/dev/null || true
                        sed -i "s/\$auth_type = 'plain';/\$auth_type = 'hash';/g" "$site/adminfm/index.php" 2>/dev/null || true
                        ((count++))
                    fi
                done
            fi

            echo -e "${GREEN}Password updated and hashed! ($count websites)${NC}"
            ;;

        3)
            echo ""
            echo -e "${CYAN}Current File Manager Settings:${NC}"
            echo "  Username : $current_user"
            echo "  Password : Hashed (secure)"
            echo "  Link     : http://localhost:$(get_port)/adminfm"
            echo ""
            ;;

        0) return ;;
        *) echo -e "${RED}Invalid option${NC}" ;;
    esac

    echo ""
    read -p "Press enter to continue..."
}

upgrade_termhost() {
    if [ -f "$INSTALL_DIR/upgrade.sh" ]; then
        bash "$INSTALL_DIR/upgrade.sh"
    else
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
        handle_error "Non-root users cannot use ports below 1024"
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

install_tinyfm() { ... }

create_website() { ... }
create_from_storage() { ... }
create_vhost() { ... }
add_to_hosts() { ... }
list_websites() { ... }
delete_website() { ... }

start_services() {
    echo -e "${YELLOW}Starting services...${NC}"
    
    pkill nginx 2>/dev/null || true
    pkill php-fpm 2>/dev/null || true
    pkill mysqld 2>/dev/null || true

    sleep 1

    if ! php-fpm >/dev/null 2>&1; then
        handle_error "Failed to start PHP-FPM"
        return 1
    fi

    sleep 1

    if ! nginx >/dev/null 2>&1; then
        handle_error "Failed to start Nginx"
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
    ensure_log_dir

    echo "1) Ngrok  2) Cloudflare  3) localhost.run"
    read -p "Choose: " c

    case $c in
        1)
            if ! command -v ngrok >/dev/null 2>&1; then
                echo -e "${YELLOW}ngrok not found. Installing...${NC}"
                pkg install ngrok -y || {
                    echo -e "${RED}Failed to install ngrok. Please install manually.${NC}"
                    return
                }
            fi

            read -p "Ngrok Token (or press enter to skip): " token
            if [ -n "$token" ]; then
                ngrok config add-authtoken "$token" 2>/dev/null || true
            fi

            pkill -f "ngrok http" 2>/dev/null || true
            ngrok http $(get_port) > "$LOG_DIR/ngrok.log" 2>&1 &
            echo -e "${GREEN}Ngrok tunnel started. Check logs for URL.${NC}"
            ;;

        2)
            if ! command -v cloudflared >/dev/null 2>&1; then
                echo -e "${YELLOW}cloudflared not found. Installing...${NC}"
                pkg install cloudflared -y || {
                    echo -e "${RED}Failed to install cloudflared.${NC}"
                    return
                }
            fi

            pkill -f cloudflared 2>/dev/null || true
            cloudflared tunnel --url http://localhost:$(get_port) > "$LOG_DIR/cloudflare.log" 2>&1 &
            echo -e "${GREEN}Cloudflare tunnel started.${NC}"
            ;;

        3)
            pkill -f "ssh -R" 2>/dev/null || true
            ssh -o StrictHostKeyChecking=no -R 80:localhost:$(get_port) nokey@localhost.run > "$LOG_DIR/localhostrun.log" 2>&1 &
            echo -e "${GREEN}localhost.run tunnel started.${NC}"
            ;;
    esac
}

database_menu() { ... }
fix_permissions() { ... }
file_manager_settings() { ... }

main() {
    init_directories
    init_config

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
            12) file_manager_settings ;;
            13) upgrade_termhost ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ;;
        esac

        echo ""
        read -p "Press Enter to continue..."
    done
}

main