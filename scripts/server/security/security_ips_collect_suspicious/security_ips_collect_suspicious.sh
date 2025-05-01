#!/bin/bash

# START README #############
# Tested/used only in Ubuntu
# END README ###############

# START PARAMETERS
# File paths — update these to match your environment
APACHE_LOG_PATH="/var/log/apache2/access.log"               # Default Apache log path for Ubuntu/Debian
APACHE_LOG_PATH_RHEL="/var/log/httpd/access_log"            # Default Apache log path for RHEL/CentOS
IP_LIST_PATH="/opt/security/error_ips.txt"                  # Path to store collected IPs
WHITELIST_PATH="/opt/security/whitelist.txt"                # Trusted IPs to ignore
# END PARAMETERS

# Temporary files
TEMP_NEW_IPS=$(mktemp /tmp/temp_ips.XXXXXX)
TEMP_FILTERED_IPS=$(mktemp /tmp/filtered_ips.XXXXXX)
DENIED_IPS=$(mktemp /tmp/denied_ips.XXXXXX)

# Select the correct Apache log path based on the system
if [ -f "$APACHE_LOG_PATH" ]; then
    APACHE_LOG_PATH=$APACHE_LOG_PATH
elif [ -f "$APACHE_LOG_PATH_RHEL" ]; then
    APACHE_LOG_PATH=$APACHE_LOG_PATH_RHEL
else
    echo "Apache log file not found. Please check the path."
    exit 1
fi

# Extract IPs with 4xx or 5xx status codes
awk '$9 ~ /^4[0-9][0-9]$/ || $9 ~ /^5[0-9][0-9]$/' "$APACHE_LOG_PATH" | awk '{print $1}' | sort -u > "$TEMP_NEW_IPS"

# Create output file if it doesn't exist
[ -f "$IP_LIST_PATH" ] || touch "$IP_LIST_PATH"

# Detect firewall (UFW, firewalld, or iptables) and get the denied IPs
if command -v ufw >/dev/null 2>&1; then
    # If UFW is installed
    echo "Using UFW to get denied IPs"
    ufw status | grep "DENY" | awk '{print $3}' > "$DENIED_IPS"
elif command -v firewall-cmd >/dev/null 2>&1; then
    # If firewalld is installed
    echo "Using firewalld to get denied IPs"
    firewall-cmd --list-blacklist | tr ' ' '\n' > "$DENIED_IPS"
elif command -v iptables >/dev/null 2>&1; then
    # If iptables is installed
    echo "Using iptables to get denied IPs"
    iptables -L INPUT -v -n | grep "DROP" | awk '{print $8}' > "$DENIED_IPS"
else
    echo "No firewall system detected. Proceeding without firewall filtering."
    touch "$DENIED_IPS"  # Create an empty file to avoid errors
fi

# Filter out IPs that are in the denied list or in the whitelist
if [ -f "$WHITELIST_PATH" ]; then
    grep -vwF -f "$WHITELIST_PATH" "$TEMP_NEW_IPS" | grep -vwF -f "$DENIED_IPS" > "$TEMP_FILTERED_IPS"
else
    cp "$TEMP_NEW_IPS" "$TEMP_FILTERED_IPS"
fi

# Merge with existing list of suspicious IPs
sort -u "$TEMP_FILTERED_IPS" "$IP_LIST_PATH" > "$IP_LIST_PATH.tmp"
mv "$IP_LIST_PATH.tmp" "$IP_LIST_PATH"

# Clean up
rm -f "$TEMP_NEW_IPS" "$TEMP_FILTERED_IPS" "$DENIED_IPS"

echo "Suspicious IPs have been processed and saved to $IP_LIST_PATH"

