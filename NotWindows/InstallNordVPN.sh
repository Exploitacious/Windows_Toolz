#!/bin/bash

# Define variables
NORDVPN_CONFIG_DIR="$HOME/nordvpn-configs"
NORDVPN_OVPN_URL="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip"
CREDENTIALS_FILE="$NORDVPN_CONFIG_DIR/vpn-credentials.txt"
CONNECTION_SCRIPT="/usr/local/bin/launch_nordvpn"
ALIAS_COMMAND="alias connectnord='sudo /usr/local/bin/launch_nordvpn'"

# Function to check for errors
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Update and install required packages
sudo apt update
check_error "Failed to update package list"

sudo apt install -y openvpn unzip wget
check_error "Failed to install required packages"

# Create directory for NordVPN configs if it doesn't exist
mkdir -p "$NORDVPN_CONFIG_DIR"
check_error "Failed to create configuration directory"

# Download and unzip NordVPN OpenVPN configuration files
cd "$NORDVPN_CONFIG_DIR"
wget -q "$NORDVPN_OVPN_URL" -O ovpn.zip
check_error "Failed to download NordVPN OpenVPN configuration files"

unzip -o ovpn.zip
check_error "Failed to unzip NordVPN OpenVPN configuration files"

# Clean up
rm ovpn.zip

# Create the connection script
cat << 'EOF' > launch_nordvpn.sh
#!/bin/bash

# Define variables
NORDVPN_CONFIG_DIR="$HOME/nordvpn-configs/ovpn_udp/"
CREDENTIALS_FILE="$HOME/nordvpn-configs/vpn-credentials.txt"

# Function to check for errors
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Resolve the correct home directory
USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)

# Check if configuration directory exists
if [ ! -d "$USER_HOME/nordvpn-configs/ovpn_udp/" ]; then
    echo "Error: Configuration directory $USER_HOME/nordvpn-configs/ovpn_udp/ does not exist."
    exit 1
fi

# Create credentials file if it doesn't exist
if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "Please enter your NordVPN credentials:"
    read -p "Username: " NORDVPN_USERNAME
    read -sp "Password: " NORDVPN_PASSWORD
    echo

    echo -e "$NORDVPN_USERNAME\n$NORDVPN_PASSWORD" > "$CREDENTIALS_FILE"
    check_error "Failed to create credentials file"

    # Restrict permissions on the credentials file
    chmod 600 "$CREDENTIALS_FILE"
    check_error "Failed to set permissions on credentials file"

    # Modify all configuration files to use the credentials file and update cipher settings
    for CONFIG_FILE in "$NORDVPN_CONFIG_DIR"/*.ovpn; do
        if ! grep -q "auth-user-pass $CREDENTIALS_FILE" "$CONFIG_FILE"; then
            echo "auth-user-pass $CREDENTIALS_FILE" >> "$CONFIG_FILE"
        fi
        # Ensure the deprecated --cipher warning is addressed
        if grep -q "cipher AES-256-CBC" "$CONFIG_FILE"; then
            sed -i '/cipher AES-256-CBC/d' "$CONFIG_FILE"
            if ! grep -q "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305" "$CONFIG_FILE"; then
                echo "data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305" >> "$CONFIG_FILE"
            fi
        fi
    done
fi

# List available configuration files
echo "Available configuration files:"
ls -1 "$USER_HOME/nordvpn-configs/ovpn_udp/"
echo

# Prompt for configuration file or random choice
read -p "Enter the name of the configuration file you want to use (e.g., us1234.nordvpn.com.udp.ovpn) or type 'random' to connect to a random one: " OVPN_FILE

# Select a random configuration file if user chose 'random'
if [ "$OVPN_FILE" == "random" ] || [ -z "$OVPN_FILE" ]; then
    OVPN_FILE=$(ls -1 "$USER_HOME/nordvpn-configs/ovpn_udp/" | shuf -n 1)
    echo "Selected random configuration file: $OVPN_FILE"
else
    # Check if the specified file exists
    if [ ! -f "$USER_HOME/nordvpn-configs/ovpn_udp/$OVPN_FILE" ]; then
        echo "Error: Configuration file $USER_HOME/nordvpn-configs/ovpn_udp/$OVPN_FILE does not exist."
        exit 1
    fi
fi

# Start OpenVPN with the specified or random configuration file
sudo openvpn --config "$USER_HOME/nordvpn-configs/ovpn_udp/$OVPN_FILE" --auth-user-pass "$CREDENTIALS_FILE"
check_error "Failed to start OpenVPN"

echo "NordVPN connected successfully using OpenVPN"
EOF

# Move the connection script to /usr/local/bin and make it executable
sudo mv launch_nordvpn.sh "$CONNECTION_SCRIPT"
sudo chmod +x "$CONNECTION_SCRIPT"
check_error "Failed to move and set permissions on connection script"

# Add alias to .zshrc if not already present
if ! grep -Fxq "$ALIAS_COMMAND" ~/.zshrc; then
    echo "$ALIAS_COMMAND" >> ~/.zshrc
    echo "Alias 'connectnord' added to ~/.zshrc"
else
    echo "Alias 'connectnord' already exists in ~/.zshrc"
fi

echo "Installation complete. Use 'connectnord' to connect to NordVPN after switching to Zsh."
