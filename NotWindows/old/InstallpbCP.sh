#!/bin/bash

# Function to install xclip
install_xclip() {
  if ! command -v xclip &> /dev/null; then
    echo "xclip not found, installing..."
    if [ -f /etc/debian_version ]; then
      sudo apt update && sudo apt install -y xclip
    elif [ -f /etc/redhat-release ]; then
      sudo yum install -y xclip
    else
      echo "Unsupported OS. Please install xclip manually."
      exit 1
    fi
  else
    echo "xclip is already installed."
  fi
}

# Function to create pbcopy and pbpaste commands
create_pbcopy_pbpaste() {
  local pbcopy_script="/usr/local/bin/pbcopy"
  local pbpaste_script="/usr/local/bin/pbpaste"

  echo "Creating pbcopy script..."
  sudo bash -c "cat > $pbcopy_script" << 'EOF'
#!/bin/bash
xclip -selection clipboard
EOF
  sudo chmod +x $pbcopy_script

  echo "Creating pbpaste script..."
  sudo bash -c "cat > $pbpaste_script" << 'EOF'
#!/bin/bash
xclip -selection clipboard -o
EOF
  sudo chmod +x $pbpaste_script
}

# Install xclip
install_xclip

# Create pbcopy and pbpaste commands
create_pbcopy_pbpaste

echo "pbcopy and pbpaste installation complete!"
