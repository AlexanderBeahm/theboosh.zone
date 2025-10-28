#!/bin/bash
# Configure iptables for Docker and UFW compatibility
# This script ensures Docker containers can be accessed from external networks
# when UFW is enabled.

set -e

echo "========================================="
echo "Docker Firewall Configuration"
echo "========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

# Install iptables-persistent if not already installed
if ! dpkg -l | grep -q iptables-persistent; then
    echo "Installing iptables-persistent..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
fi

# Function to check if a rule exists
rule_exists() {
    local chain=$1
    local rule=$2
    iptables -C $chain $rule 2>/dev/null
    return $?
}

# Wait for Docker to create DOCKER-USER chain
echo "Waiting for Docker to initialize..."
max_attempts=30
attempt=0
while ! iptables -L DOCKER-USER -n >/dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "Error: Docker DOCKER-USER chain not found after ${max_attempts} seconds"
        echo "Make sure Docker is running: systemctl status docker"
        exit 1
    fi
    sleep 1
done
echo "Docker DOCKER-USER chain found"

# Remove any existing RETURN rules at the beginning of DOCKER-USER
echo "Cleaning up existing DOCKER-USER rules..."
while iptables -L DOCKER-USER -n --line-numbers | grep -q "^1.*RETURN"; do
    iptables -D DOCKER-USER 1
    echo "Removed RETURN rule at position 1"
done

# Add rules for HTTP and HTTPS if they don't exist
echo "Configuring firewall rules for ports 80 and 443..."

# Check network interface (usually eth0, but could be different)
PRIMARY_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$PRIMARY_IFACE" ]; then
    PRIMARY_IFACE="eth0"
    echo "Warning: Could not detect primary interface, using eth0"
else
    echo "Detected primary interface: $PRIMARY_IFACE"
fi

# Remove duplicate rules if they exist
iptables -L DOCKER-USER -n --line-numbers | grep "tcp dpt:443" | tac | while read line; do
    line_num=$(echo $line | awk '{print $1}')
    if [ "$line_num" != "1" ]; then
        iptables -D DOCKER-USER $line_num 2>/dev/null || true
    fi
done

iptables -L DOCKER-USER -n --line-numbers | grep "tcp dpt:80" | tac | while read line; do
    line_num=$(echo $line | awk '{print $1}')
    if [ "$line_num" != "1" ] && [ "$line_num" != "2" ]; then
        iptables -D DOCKER-USER $line_num 2>/dev/null || true
    fi
done

# Add ACCEPT rules for HTTPS (443) and HTTP (80)
if ! rule_exists "DOCKER-USER -i $PRIMARY_IFACE -p tcp --dport 443 -j ACCEPT"; then
    iptables -I DOCKER-USER 1 -i $PRIMARY_IFACE -p tcp --dport 443 -j ACCEPT
    echo "Added rule: ACCEPT tcp port 443"
fi

if ! rule_exists "DOCKER-USER -i $PRIMARY_IFACE -p tcp --dport 80 -j ACCEPT"; then
    iptables -I DOCKER-USER 2 -i $PRIMARY_IFACE -p tcp --dport 80 -j ACCEPT
    echo "Added rule: ACCEPT tcp port 80"
fi

# Ensure RETURN rule exists at the end
if ! iptables -L DOCKER-USER -n | tail -n 1 | grep -q "RETURN"; then
    iptables -A DOCKER-USER -j RETURN
    echo "Added RETURN rule at end of chain"
fi

# Display current DOCKER-USER chain
echo ""
echo "Current DOCKER-USER chain:"
iptables -L DOCKER-USER -n -v --line-numbers

# Save iptables rules
echo ""
echo "Saving iptables rules..."
netfilter-persistent save

echo ""
echo "========================================="
echo "Docker firewall configuration complete!"
echo "========================================="
echo ""
echo "Ports 80 and 443 are now accessible from external networks."
echo "Rules will persist across reboots."
