#!/bin/bash
# ==========================================
# ocserv_stats.sh
# Script for collecting OpenConnect VPN (ocserv) metrics for Zabbix Agent 2
# ==========================================

STATUS_JSON=$(sudo /usr/bin/occtl --json show status 2>/dev/null)
USERS_JSON=$(sudo /usr/bin/occtl --json show users 2>/dev/null)
PASSWD_FILE="/etc/ocserv/ocpasswd"

# Check if ocserv is available
if [ -z "$STATUS_JSON" ]; then
    echo "0"
    exit 1
fi

case "$1" in
    # ==========================================
    # --- General server metrics ---
    # ==========================================
    active_sessions) echo "$STATUS_JSON" | jq -r '.["Active sessions"] // 0' ;;
    total_sessions) echo "$STATUS_JSON" | jq -r '.["Total sessions"] // 0' ;;
    auth_failures) echo "$STATUS_JSON" | jq -r '.["Total authentication failures"] // 0' ;;
    ips_banned) echo "$STATUS_JSON" | jq -r '.["IPs in ban list"] // 0' ;;
    uptime_start) echo "$STATUS_JSON" | jq -r '.["Up since"] // "unknown"' ;;
    uptime_seconds) echo "$STATUS_JSON" | jq -r '.uptime // 0' ;;
    traffic_in) echo "$STATUS_JSON" | jq -r '.raw_rx // 0' ;;
    traffic_out) echo "$STATUS_JSON" | jq -r '.raw_tx // 0' ;;

    # ==========================================
    # --- LLD for users (from ocpasswd) ---
    # ==========================================
    user_list)
        if [ -f "$PASSWD_FILE" ]; then
            awk -F: '{print $1}' "$PASSWD_FILE" | grep -v '^#' | while read -r user; do
                if [ -n "$user" ]; then
                    echo "{\"{#USERNAME}\":\"$user\"}"
                fi
            done | jq -s '.'
        else
            echo "[]"
        fi
        ;;
    
    # --- Specific user metrics ---
    user_status)
        USERNAME="$2"
        IS_ONLINE=$(echo "$USERS_JSON" | jq -r --arg u "$USERNAME" '.[] | select(.Username == $u) | .Username' 2>/dev/null)
        if [ -n "$IS_ONLINE" ]; then echo "1"; else echo "0"; fi
        ;;
    user_traffic_in)
        USERNAME="$2"
        RES=$(echo "$USERS_JSON" | jq -r --arg u "$USERNAME" '.[] | select(.Username == $u) | .RX' 2>/dev/null)
        if [ -z "$RES" ]; then echo "0"; else echo "$RES"; fi
        ;;
    user_traffic_out)
        USERNAME="$2"
        RES=$(echo "$USERS_JSON" | jq -r --arg u "$USERNAME" '.[] | select(.Username == $u) | .TX' 2>/dev/null)
        if [ -z "$RES" ]; then echo "0"; else echo "$RES"; fi
        ;;
    user_remote_ip)
        USERNAME="$2"
        echo "$USERS_JSON" | jq -r --arg u "$USERNAME" '.[] | select(.Username == $u) | .["Remote IP"] // "unknown"'
        ;;
    user_user_agent)
        USERNAME="$2"
        echo "$USERS_JSON" | jq -r --arg u "$USERNAME" '.[] | select(.Username == $u) | .["User-Agent"] // "unknown"'
        ;;
    user_hostname)
        USERNAME="$2"
        echo "$USERS_JSON" | jq -r --arg u "$USERNAME" '.[] | select(.Username == $u) | .Hostname // "unknown"'
        ;;
    user_connected_at)
        USERNAME="$2"
        echo "$USERS_JSON" | jq -r --arg u "$USERNAME" '.[] | select(.Username == $u) | .["Connected at"] // "unknown"'
        ;;

    # ==========================================
    # --- LLD and status for banned IPs ---
    # ==========================================
    ban_list)
        BANS_JSON=$(sudo /usr/bin/occtl -j show ip bans 2>/dev/null)
        if [ -n "$BANS_JSON" ] && [ "$BANS_JSON" != "[]" ]; then
            echo "$BANS_JSON" | jq -c '[.[] | {"{#BANNED_IP}": .IP}]'
        else
            echo "[]"
        fi
        ;;
    ban_status)
        IP="$2"
        BANS_JSON=$(sudo /usr/bin/occtl -j show ip bans 2>/dev/null)
        if [ -n "$BANS_JSON" ]; then
            IS_BANNED=$(echo "$BANS_JSON" | jq -r --arg ip "$IP" '.[] | select(.IP == $ip) | .IP')
            if [ -n "$IS_BANNED" ]; then echo "1"; else echo "0"; fi
        else
            echo "0"
        fi
        ;;

    # ==========================================
    # --- Unknown commands fallback ---
    # ==========================================
    *)
        echo "0"
        exit 1
        ;;
esac
