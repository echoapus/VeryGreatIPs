#!/bin/bash

# Log file path
LOG_FILE="/var/log/asban.log"

# Clear the log file at the start of execution
: > "$LOG_FILE"

# Function to log messages with timestamp and append to the log file
log() {
    local MESSAGE=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $MESSAGE" | tee -a "$LOG_FILE"
}

# List of Autonomous System Numbers (ASNs) to block
AS_LIST=("4134" "4837" "58453" "4812" "4538" "4808" "17816")

# Check if required tools are installed
MISSING=""
for cmd in ipset iptables ip6tables whois; do
    command -v "$cmd" &>/dev/null || MISSING="$MISSING $cmd"
done
if [ -n "$MISSING" ]; then
    log "Error: Missing required tools:$MISSING. Please install them first."
    exit 1
fi

# Remove existing ipsets and associated iptables/ip6tables rules
remove_matching_ipsets() {
    log "Removing existing ipsets and associated rules matching 'as*_' pattern..."

    sudo ipset list -n | grep -E '^as.*_.' | while read -r ipset_name; do
        log "Removing iptables rules for $ipset_name (if any)."
        sudo iptables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null || true
        sudo ip6tables -D INPUT -m set --match-set "$ipset_name" src -j DROP 2>/dev/null || true

        log "Flushing ipset: $ipset_name"
        sudo ipset flush "$ipset_name" 2>/dev/null || log "Warning: Failed to flush $ipset_name."

        log "Destroying ipset: $ipset_name"
        sudo ipset destroy "$ipset_name" 2>/dev/null || log "Warning: Failed to destroy $ipset_name."
    done
}

# Create ipsets for a specific ASN
create_ipset() {
    local AS=$1
    log "Creating ipsets for AS${AS}..."

    sudo ipset create "as${AS}_v4" hash:net family inet 2>/dev/null || \
        log "Warning: Failed to create IPv4 ipset for AS${AS}."
    sudo ipset create "as${AS}_v6" hash:net family inet6 2>/dev/null || \
        log "Warning: Failed to create IPv6 ipset for AS${AS}."
}

# Add IP to ipset with retry mechanism, stop processing if failed
add_ip_or_stop() {
    local IPSET=$1
    local IP=$2

    if ! sudo ipset add "$IPSET" "$IP" 2>/dev/null; then
        log "Warning: Failed to add $IP to $IPSET. Retrying..."
        sleep 1
        if ! sudo ipset add "$IPSET" "$IP" 2>/dev/null; then
            log "Error: Failed to add $IP to $IPSET after retry. Stopping this ASN."
            return 1  # Stop processing this ASN
        fi
    fi
    return 0  # Successfully added
}

# Fetch and add IPv4 ranges for a specific ASN
fetch_and_add_ipv4() {
    local AS=$1
    local IPSET="as${AS}_v4"
    log "Fetching IPv4 ranges for AS${AS}..."

    whois -h whois.radb.net -- "-i origin AS${AS}" | awk '/^route:/ {print $2}' | while read -r ip; do
        if ! add_ip_or_stop "$IPSET" "$ip"; then
            log "Stopping further processing for AS${AS} (IPv4)."
            return 1
        fi
    done
    return 0
}

# Fetch and add IPv6 ranges for a specific ASN
fetch_and_add_ipv6() {
    local AS=$1
    local IPSET="as${AS}_v6"
    log "Fetching IPv6 ranges for AS${AS}..."

    whois -h whois.radb.net -- "-i origin AS${AS}" | awk '/^route6:/ {print $2}' | while read -r ip; do
        if ! add_ip_or_stop "$IPSET" "$ip"; then
            log "Stopping further processing for AS${AS} (IPv6)."
            return 1
        fi
    done
    return 0
}

# Remove existing ipsets and rules
remove_matching_ipsets

# Create and populate ipsets for each ASN
for AS in "${AS_LIST[@]}"; do
    create_ipset "${AS}"
    if ! fetch_and_add_ipv4 "${AS}"; then
        log "Skipping AS${AS} after IPv4 processing failure."
        continue
    fi
    if ! fetch_and_add_ipv6 "${AS}"; then
        log "Skipping AS${AS} after IPv6 processing failure."
        continue
    fi
    sleep 5  # Avoid excessive whois requests
done

# Set up iptables and ip6tables rules for the created ipsets
log "Setting up iptables and ip6tables rules..."
for AS in "${AS_LIST[@]}"; do
    sudo iptables -I INPUT -m set --match-set "as${AS}_v4" src -j DROP
    sudo ip6tables -I INPUT -m set --match-set "as${AS}_v6" src -j DROP
done

# Display the current ipset list
log "Current ipset lists:"
sudo ipset list -n | tee -a "$LOG_FILE"

log "Blocking of specified AS numbers complete."
