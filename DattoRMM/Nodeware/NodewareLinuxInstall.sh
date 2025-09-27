#!/bin/bash

#================================================================================
#
#          FILE:  install_nodeware_linux_universal.sh
#
#         USAGE:  This script is intended for use in an RMM system like Datto.
#
#   DESCRIPTION:  Installs the Nodeware agent on all supported Linux systems.
#                 - Automatically detects Debian/Ubuntu vs. RHEL/CentOS.
#                 - Uses the latest package URLs as of September 2025.
#                 - Registers the agent with the provided Customer ID.
#
#================================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- CONFIGURE CUSTOMER ID ---
# This variable is passed directly from the Datto RMM environment.
# Ensure you have a site variable named 'nodeWareCustomerID'.
customerID="$nodeWareCustomerID"
# -----------------------------


## **1. Pre-flight Checks**
echo "Performing pre-flight checks..."

# Check for Customer ID
if [ -z "$customerID" ]; then
    echo "ERROR: nodeWareCustomerID is not set. Please check the variable name and case at the Site or Component level."
    exit 1
fi

# Check for Root Privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please use sudo." >&2
    exit 1
fi


## **2. Detect Linux Distribution**
echo "Detecting Linux distribution..."

# Source the os-release file to get distribution info
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "Cannot detect OS: /etc/os-release not found."
    exit 1
fi

# Determine package type and set URLs based on the OS family
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID_LIKE" == "debian" ]]; then
    PKG_MANAGER="apt-get"
    TYPE="debian"
    BASE_URL="https://downloads.nodeware.com/agent/linux/debian/nodeware-agent-base_5.1.0.deb"
    CORE_URL="https://downloads.nodeware.com/agent/linux/debian/nodeware-agent-core_5.1.0.deb"
    BASE_FILE="nodeware-agent-base.deb"
    CORE_FILE="nodeware-agent-core.deb"

elif [[ "$ID" == "rhel" || "$ID" == "centos" || "$ID" == "fedora" || "$ID_LIKE" == "rhel" ]]; then
    PKG_MANAGER="yum"
    TYPE="rhel"
    BASE_URL="https://downloads.nodeware.com/agent/linux/rhel/nodeware-agent-base-5.0.0.x86_64.rpm"
    CORE_URL="https://downloads.nodeware.com/agent/linux/rhel/nodeware-agent-core-5.0.4.x86_64.rpm"
    BASE_FILE="nodeware-agent-base.rpm"
    CORE_FILE="nodeware-agent-core.rpm"

else
    echo "Unsupported Linux distribution: $PRETTY_NAME"
    exit 1
fi

echo "Distribution detected as: $TYPE. Using package manager: $PKG_MANAGER."


## **3. Download and Install Agent**
# Create a temporary directory for the download
TEMP_DIR=$(mktemp -d -t nodeware-install-XXXXXXXXXX)
cd "$TEMP_DIR"
echo "Working in temporary directory: $TEMP_DIR"

echo "Downloading Nodeware agent packages..."
wget -q -O "$BASE_FILE" "$BASE_URL"
wget -q -O "$CORE_FILE" "$CORE_URL"

echo "Installing packages and dependencies..."
if [ "$PKG_MANAGER" == "apt-get" ]; then
    apt-get update -y
    apt-get install -y "./$BASE_FILE"
    apt-get install -y "./$CORE_FILE"
elif [ "$PKG_MANAGER" == "yum" ]; then
    yum install -y "./$BASE_FILE"
    yum install -y "./$CORE_FILE"
fi


## **4. Register and Start Service**
echo "Registering Nodeware agent with Customer ID..."
/usr/local/bin/nodeware/NodewareAgent register customerid="$customerID"

echo "Creating and starting Nodeware service..."
/usr/local/bin/nodeware/NodewareAgent service create


## **5. Cleanup**
echo "Cleaning up installation files..."
rm -rf "$TEMP_DIR"

echo "Nodeware Agent installation and registration complete!"

exit 0