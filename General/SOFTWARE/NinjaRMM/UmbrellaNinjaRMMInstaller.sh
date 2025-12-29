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
#  DESCRIPTION:  Installs NinjaOne agent on Debian/Ubuntu.
#                - PIPE-SAFE: Prevents apt from stealing STDIN.
#                - DYNAMIC: Auto-detects service name.
#
#================================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# URL for the NinjaOne agent .deb package
AGENT_URL="https://us2.ninjarmm.com/agent/installer/a2a3c726-200f-4fa6-964f-9d9aabbe4a28/11.0.5635/NinjaOne-Agent-AlexTestingCribo-Cribo-Auto-x86-64.deb"

# Local filename for the downloaded package
AGENT_FILE="ninjaone_agent.deb"
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
    echo "ERROR: This script is intended for Debian-based systems (like Ubuntu, Mint) only."
    exit 1
fi
echo "Checks passed: Running as root on a Debian-based system."

## 2. Download and Install Agent
echo "--- Downloading and installing the NinjaOne agent..."

# Create a secure, temporary directory
TEMP_DIR=$(mktemp -d -t ninjaone-install-XXXXXXXXXX)
cd "$TEMP_DIR"
echo "Created temporary directory: $TEMP_DIR"

echo "Downloading the NinjaOne agent package..."
wget -q -O "$AGENT_FILE" "$AGENT_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: Download failed. Please check the AGENT_URL and your network connection."
    rm -rf "$TEMP_DIR"
    exit 1
fi
echo "Download complete."

echo "Installing the package..."
# Update package lists - Redirecting stdin to /dev/null is CRITICAL for piped execution
apt-get update -y > /dev/null < /dev/null

# Install with non-interactive frontend and disable STDIN usage
# This prevents apt from "eating" the rest of this script if run via curl | bash
DEBIAN_FRONTEND=noninteractive apt-get install -y "./$AGENT_FILE" < /dev/null

echo "Installation complete."

## 3. Dynamic Service Detection & Start
echo "--- Configuring the NinjaOne agent service..."

# Reload systemd daemon to recognize the new service
systemctl daemon-reload

# Dynamically find the service name. Ninja sometimes changes names (ninjaagent vs ninjarmm-agent).
# We look for any service unit containing "ninja" in the name.
SERVICE_NAME=$(systemctl list-unit-files --type=service --no-legend | grep -i "ninja" | head -n 1 | awk '{print $1}')

if [ -n "$SERVICE_NAME" ]; then
    echo "Detected NinjaOne service: $SERVICE_NAME"
    
    echo "Enabling and starting '$SERVICE_NAME'..."
    systemctl enable --now "$SERVICE_NAME"
    
    # Verify it is running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
         echo "SUCCESS: $SERVICE_NAME is running."
    else
         echo "WARNING: $SERVICE_NAME was enabled but is not currently active."
    fi
else
    echo "WARNING: Could not auto-detect a service named *ninja*. You may need to start it manually."
    # List all services to help user debug
    systemctl list-unit-files --type=service | grep -i "ninja" || true
fi

## 4. Cleanup
echo "--- Cleaning up installation files..."
cd /
rm -rf "$TEMP_DIR"
echo "Temporary directory removed."

echo "================================================="
echo " NinjaOne Agent installation script has finished."
echo "================================================="

exit 0