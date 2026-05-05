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

missing_count=0
for path in "${PATHS[@]}"; do
    if [[ -e "$path" ]]; then
        echo -e "  ${GREEN}✓${NC} $path"
    else
        echo -e "  ${RED}✗${NC} $path ${RED}(missing)${NC}"
        ((missing_count++))
    fi
done

if [[ $missing_count -gt 0 ]]; then
    echo -e "  ${RED}FIX: cmsh -c \"softwareimage; use default-image; createramdisk\"${NC}"
fi

echo ""
echo -e "${BLUE}Network Connections (nmcli):${NC}"
if timeout 5 nmcli con show &>/dev/null; then
    echo "  Connections:"
    timeout 5 nmcli con show 2>/dev/null | tail -n +2 | awk -v RED="$RED" -v NC="$NC" '{
        name=$1
        for(i=2; i<=NF-2; i++) name = name " " $i
        type=$(NF-1)
        device=$NF

        if (device == "--") {
            printf "    %-30s → %s %s(orphaned)%s\n", name, type, RED, NC
            orphaned[name]=1
        } else {
            printf "    %-30s → %s → %s\n", name, type, device
            devices[device]++
            conn_on_dev[device] = conn_on_dev[device] name "; "
        }
    }
    END {
        orphaned_count = length(orphaned)
        if (orphaned_count > 0) {
            print ""
            print "  " RED "⚠ WARNING: Found " orphaned_count " orphaned connection(s) with no device assigned" NC
            print "    FIX: nmcli con delete <connection-name>"
        }

        has_duplicates=0
        for (dev in devices) {
            if (devices[dev] > 1) {
                has_duplicates=1
                break
            }
        }
        if (has_duplicates) {
            print ""
            print "  " RED "⚠ WARNING: Duplicate network device connections detected:" NC
            for (dev in devices) {
                if (devices[dev] > 1) {
                    print "    Device " dev " has " devices[dev] " active connections"
                    print "      FIX: nmcli con delete <duplicate-connection-name>"
                }
            }
        }
    }'
else
    echo -e "  ${YELLOW}⚠ nmcli unavailable${NC}"
fi

echo ""
echo -e "${BLUE}Cluster Devices (cmsh):${NC}"
if timeout 5 cmsh -c "device list -f type,hostname,mac,ip,network" &>/dev/null; then
    timeout 5 cmsh -c "device list -f type,hostname,mac,ip,network" 2>/dev/null | sed 's/^/  /'
    echo ""
    echo -e "  ${RED}FIX (if IPs above are duplicated):${NC}"
    echo "    cmsh -c \"device use <hostname>; interfaces; use bootif; set ip <correct-ip>; commit\""
else
    echo -e "  ${YELLOW}⚠ cmsh not responding (timeout)${NC}"
fi

echo ""
echo -e "${BLUE}Time Servers Configuration:${NC}"
timeservers=$(timeout 5 cmsh -c "partition use base; get timeservers" 2>/dev/null)
if [[ -z "$timeservers" ]]; then
    echo -e "  ${RED}✗ No timeservers configured${NC}"
    echo "    FIX: cmsh -c \"partition use base; set timeservers <ntphost>\""
else
    echo -e "  ${GREEN}✓ Timeservers configured:${NC}"
    echo "$timeservers" | sed 's/^/    /'
fi

echo ""
echo -e "${BLUE}Summary:${NC}"
echo "  Timestamp: $(date)"
