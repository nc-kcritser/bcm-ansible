#!/bin/bash

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVICES=(
    "tftpd.socket"
    "tftpd.service*"
    "cmd"
    "dhcpd"
    "mariadb"
)

check_service_status() {
    local service=$1
    local enabled=0
    local active=0

    # Check if enabled
    if systemctl is-enabled "$service" &>/dev/null; then
        enabled=1
    fi

    # Check if active
    if systemctl is-active "$service" &>/dev/null; then
        active=1
    fi

    echo "$enabled $active"
}

format_status() {
    local enabled=$1
    local active=$2

    if [[ $enabled -eq 1 && $active -eq 1 ]]; then
        echo -e "${GREEN}✓ Enabled & Active${NC}"
    elif [[ $enabled -eq 1 && $active -eq 0 ]]; then
        echo -e "${YELLOW}⚠ Enabled but Inactive${NC}"
    elif [[ $enabled -eq 0 && $active -eq 1 ]]; then
        echo -e "${YELLOW}⚠ Active but Not Enabled${NC}"
    else
        echo -e "${RED}✗ Disabled & Inactive${NC}"
    fi
}

echo -e "${BLUE}=== System Health Status ===${NC}\n"

echo -e "${BLUE}Services:${NC}"
for service in "${SERVICES[@]}"; do
    service_name="${service%\*}"
    has_note="${service##*$service_name}"
    read enabled active <<< "$(check_service_status "$service_name")"
    status=$(format_status "$enabled" "$active")
    if [[ -n "$has_note" ]]; then
        printf "  %-20s %s (socket revives if needed)\n" "$service_name*" "$status"
    else
        printf "  %-20s %s\n" "$service_name" "$status"
    fi
done

echo ""
echo -e "${BLUE}Disk Space:${NC}"
df -h | awk 'NR==1 {print; next}
    /tmpfs|devtmpfs|efivarfs|tracefs/ {next}
    /\/boot$|\/boot\/efi$/ {next}
    {
    usage=$(gsub(/%/, "", $5))
    if (usage > 80) {
        printf "  \033[0;31m%s\033[0m\n", $0
    } else if (usage > 60) {
        printf "  \033[1;33m%s\033[0m\n", $0
    } else {
        printf "  \033[0;32m%s\033[0m\n", $0
    }
}'

echo ""
echo -e "${BLUE}Image & Boot Configuration:${NC}"

# Check critical paths
PATHS=(
    "/cm/images/default-image/boot/"
    "/cm/images/default-image/boot/vmlinuz"
)

for path in "${PATHS[@]}"; do
    if [[ -e "$path" ]]; then
        echo -e "  ${GREEN}✓${NC} $path"
    else
        echo -e "  ${RED}✗${NC} $path ${RED}(missing)${NC}"
    fi
done

echo ""
echo -e "${BLUE}Network Connections (nmcli):${NC}"
if timeout 5 nmcli -t -f NAME,DEVICE connection show 2>/dev/null | grep -q .; then
    echo "  Connections:"
    timeout 5 nmcli -t -f NAME,DEVICE connection show 2>/dev/null | awk -F: '{
        if ($1 != "" && $2 != "") {
            printf "    %-30s → %s\n", $1, $2
        }
    }'
else
    echo -e "  ${YELLOW}⚠ No connections found or nmcli unavailable${NC}"
fi

echo ""
echo -e "${BLUE}Cluster Devices (cmsh):${NC}"
if timeout 5 cmsh -c "device; list" &>/dev/null; then
    timeout 5 cmsh -c "device; list" | sed 's/^/  /'
else
    echo -e "  ${YELLOW}⚠ cmsh not responding (timeout)${NC}"
fi

echo ""
echo -e "${BLUE}Time Servers Configuration:${NC}"
timeservers=$(timeout 5 cmsh -c "partition use base; get timeservers" 2>/dev/null)
if [[ -z "$timeservers" ]]; then
    echo -e "  ${RED}✗ No timeservers configured${NC}"
else
    echo -e "  ${GREEN}✓ Timeservers configured:${NC}"
    echo "$timeservers" | sed 's/^/    /'
fi

echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  Timestamp: $(date)"
