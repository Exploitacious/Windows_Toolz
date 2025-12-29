#!/bin/bash

#================================================================================
#
#        Site: Umbrella IT Solutions
#        FILE:  install_ninjaone_agent.sh
#
#       USAGE:  sudo ./install_ninjaone_agent.sh
#               OR via curl pipe:
#               curl -fsSL https://.../script.sh | sudo bash
#
#  DESCRIPTION:  Installs NinjaOne agent + System Tools on Debian/Ubuntu.
#                - PIPE-SAFE: Prevents apt from stealing STDIN.
#                - DYNAMIC: Auto-detects service name.
#
#================================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# URL for the NinjaOne agent .deb package
AGENT_URL=""

# Local filename for the downloaded package
AGENT_FILE="ninjaone_agent.deb"

# System utilities to install
# NOTE: 'glibc' is installed as 'libc6' on Debian systems
SYSTEM_TOOLS="unzip ethtool smartmontools dmidecode libc6 parted network-manager"
# ---------------------

## 1. Pre-flight Checks
echo "--- Performing pre-flight checks..."

# Check for Root Privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root. Please use sudo." >&2
    exit 1
fi

# Check for a Debian-based system
if ! [ -f /etc/debian_version ]; then
    echo "ERROR: This script is intended for Debian-based systems only."
    exit 1
fi
echo "Checks passed: Root + Debian detected."

## 2. Install System Dependencies
echo "--- Installing system utilities..."
echo "Target packages: $SYSTEM_TOOLS"

# Update package lists - PIPE SAFE
apt-get update -y > /dev/null < /dev/null

# Install tools - PIPE SAFE
# DEBIAN_FRONTEND=noninteractive prevents popups (like for NetworkManager)
DEBIAN_FRONTEND=noninteractive apt-get install -y $SYSTEM_TOOLS < /dev/null
echo "System utilities installed."

## 3. Download and Install Ninja Agent
echo "--- Downloading and installing the NinjaOne agent..."

TEMP_DIR=$(mktemp -d -t ninjaone-install-XXXXXXXXXX)
cd "$TEMP_DIR"

echo "Downloading package..."
wget -q -O "$AGENT_FILE" "$AGENT_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: Download failed. Check URL/Network."
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "Installing Agent..."
DEBIAN_FRONTEND=noninteractive apt-get install -y "./$AGENT_FILE" < /dev/null
echo "Agent installation complete."

## 4. Dynamic Service Detection & Start
echo "--- Configuring the NinjaOne agent service..."

systemctl daemon-reload
# Dynamically find the service name (ninjaagent vs ninjarmm-agent)
SERVICE_NAME=$(systemctl list-unit-files --type=service --no-legend | grep -i "ninja" | head -n 1 | awk '{print $1}')

if [ -n "$SERVICE_NAME" ]; then
    echo "Detected NinjaOne service: $SERVICE_NAME"
    systemctl enable --now "$SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
         echo "SUCCESS: $SERVICE_NAME is running."
    else
         echo "WARNING: $SERVICE_NAME was enabled but is not currently active."
    fi
else
    echo "WARNING: Could not auto-detect a service named *ninja*."
fi

## 5. Cleanup
echo "--- Cleaning up..."
cd /
rm -rf "$TEMP_DIR"

echo "================================================="
echo " NinjaOne Agent installation script has finished."
echo "================================================="

exit 0