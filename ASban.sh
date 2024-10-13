#!/bin/bash

echo "Clearing old iptables rules and ipset if they exist..."

# Remove old iptables rule if exists
sudo iptables -D INPUT -m set --match-set as_blocklist src -j DROP 2>/dev/null

# Destroy the old ipset if exists
sudo ipset destroy as_blocklist 2>/dev/null

# Ensure xtables-addons directory exists
echo "Creating directory for xtables-addons..."
sudo mkdir -p /etc/xtables-addons/

# Autonomous System Numbers to block
AS_LIST=("4134" "4837" "58453" "4812" "4538" "4808" "17816")

# Check if required tools are installed
for cmd in ipset iptables whois; do
    if ! command -v $cmd &>/dev/null; then
        echo "Error: $cmd is not installed. Please install it first."
        exit 1
    fi
done

# Create a new ipset for the AS blocklist
echo "Creating ipset for AS blocklist..."
sudo ipset create as_blocklist hash:net

# Function to fetch and add IPs to ipset
fetch_and_add_ips() {
    AS=$1
    echo "Fetching IP ranges for AS${AS}..."
    # Fetch IP ranges using whois and add to ipset directly
    whois -h whois.radb.net -- "-i origin AS${AS}" | grep "route:" | awk '{print $2}' | while read -r ip; do
        if [ -n "$ip" ]; then
            sudo ipset add as_blocklist "$ip"
        else
            echo "Error: Failed to fetch IP ranges for AS${AS}."
        fi
    done
}

# Fetch IP ranges for each AS sequentially
for AS in "${AS_LIST[@]}"; do
    fetch_and_add_ips "${AS}"
    sleep 5  # Sleep to avoid overwhelming the whois server
done

echo "Setting up iptables rule to block AS list..."
sudo iptables -I INPUT -m set --match-set as_blocklist src -j DROP

echo "Current iptables rules:"
sudo iptables -L

echo "Current ipset content:"
sudo ipset list as_blocklist

echo "Blocking of specified AS numbers complete."
