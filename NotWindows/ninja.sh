#!/bin/bash

#================================================================================
#
#         Site: Umbrella IT Solutions
#         FILE:  install_ninjaone_agent.sh
#
#        USAGE:  sudo ./install_ninjaone_agent.sh
#
#  DESCRIPTION:  Installs the NinjaOne agent on Debian-based Linux systems.
#                - Ensures script is run with root privileges.
#                - Verifies the OS is Debian-based (e.g., Debian, Ubuntu).
#                - Downloads the specified agent version into a temporary directory.
#                - Installs the agent and its dependencies using apt.
#                - Enables and starts the agent's systemd service.
#                - Cleans up all temporary files after installation.
#
#================================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# URL for the NinjaOne agent .deb package
AGENT_URL="https://us2.ninjarmm.com/agent/installer/43cb711a-1ae3-4b9d-b826-76f2ad96b1bf/10.0.4634/NinjaOne-Agent-UmbrellaInternalInfrastructure-Primary-Auto-x86-64.deb"

# Local filename for the downloaded package
AGENT_FILE="ninjaone_agent.deb"

# The name of the systemd service for the agent
# NOTE: This is a common name; verify if installation issues occur.
SERVICE_NAME="ninjaagent"
# ---------------------


## 1. Pre-flight Checks
echo "--- Performing pre-flight checks..."

# Check for Root Privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root. Please use sudo." >&2
    exit 1
fi

# Check for a Debian-based system by verifying the existence of /etc/debian_version
if ! [ -f /etc/debian_version ]; then
    echo "ERROR: This script is intended for Debian-based systems (like Ubuntu, Mint) only."
    exit 1
fi
echo "Checks passed: Running as root on a Debian-based system."


## 2. Download and Install Agent
echo "--- Downloading and installing the NinjaOne agent..."

# Create a secure, temporary directory for the download
TEMP_DIR=$(mktemp -d -t ninjaone-install-XXXXXXXXXX)
cd "$TEMP_DIR"
echo "Created temporary directory: $TEMP_DIR"

echo "Downloading the NinjaOne agent package..."
# Use wget with -q (quiet) and -O (output file) flags
wget -q -O "$AGENT_FILE" "$AGENT_URL"
if [ $? -ne 0 ]; then
    echo "ERROR: Download failed. Please check the AGENT_URL and your network connection."
    rm -rf "$TEMP_DIR" # Clean up on failure
    exit 1
fi
echo "Download complete."

echo "Installing the package and its dependencies..."
# Update package lists to ensure dependencies are available
apt-get update -y > /dev/null
# Use 'apt-get install' on a local .deb file to automatically handle dependencies
apt-get install -y "./$AGENT_FILE"
echo "Installation complete."


## 3. Start and Enable Service
echo "--- Configuring the NinjaOne agent service..."

# Check if the service exists before attempting to manage it
if systemctl list-units --full --all | grep -q "$SERVICE_NAME.service"; then
    echo "Enabling and starting the '$SERVICE_NAME' service..."
    # Use 'enable --now' to both enable the service on boot and start it immediately
    systemctl enable --now "$SERVICE_NAME"
    echo "Service started and enabled successfully."
else
    echo "WARNING: Service '$SERVICE_NAME.service' was not found. The agent may not have installed correctly, or it may use a different service name."
    # This is a warning, not a fatal error, as the user may need to find the correct service name manually.
fi


## 4. Cleanup
echo "--- Cleaning up installation files..."
rm -rf "$TEMP_DIR"
echo "Temporary directory removed."

echo "================================================="
echo " NinjaOne Agent installation script has finished."
echo "================================================="

exit 0
