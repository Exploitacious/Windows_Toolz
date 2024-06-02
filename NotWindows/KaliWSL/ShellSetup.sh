#!/bin/bash
# Script to set up Kali in WSL environment on a clean install

# Colors
GREEN='\033[0;32m'

## Install latest Keys and update repos 
sudo wget https://archive.kali.org/archive-key.asc -O /etc/apt/trusted.gpg.d/kali-archive-keyring.asc
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"|sudo tee /etc/apt/sources.list.d/brave-browser-release.list
# Hold any broken packages
echo libc6:amd64 hold | sudo dpkg --set-selections
# To undo: echo libc6:amd64 install | sudo dpkg --set-selections
### For some reason, libc6 was broken when installing from a fresh Kali setup. Install it after setting everything up.

# Add additional 

# clean
touch ~/.hushlogin
sudo apt-get clean
sudo dpkg --configure -a
sudo apt install -f

# Enable experimental repositories
sudo kali-tweaks


## Install Zsh for all Users
#!/bin/bash
# Function to install Zsh
install_zsh() {
  if ! command -v zsh &> /dev/null; then
    echo "Zsh not found, installing..."
    if [ -f /etc/debian_version ]; then
      sudo apt update && sudo apt install -y zsh
    elif [ -f /etc/redhat-release ]; then
      sudo yum install -y zsh
    else
      echo "Unsupported OS. Please install Zsh manually."
      exit 1
    fi
  else
    echo "Zsh is already installed."
  fi
}
# Function to install Oh My Zsh for a user
install_oh_my_zsh() {
  local user=$1
  local home_dir=$(eval echo ~$user)
  local zshrc="$home_dir/.zshrc"
  local oh_my_zsh_dir="$home_dir/.oh-my-zsh"
  
  if [ ! -d "$oh_my_zsh_dir" ]; then
    echo "Installing Oh My Zsh for $user..."
    sudo -u $user sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended " || {
      echo "Oh My Zsh installation failed for $user"
      return 1
    }
  else
    echo "Oh My Zsh is already installed for $user."
  fi
  
  if [ ! -f "$zshrc" ]; then
    echo "Creating .zshrc for $user..."
    cp "$oh_my_zsh_dir/templates/zshrc.zsh-template" "$zshrc"
    sudo chown $user:$user "$zshrc"
  else
    echo ".zshrc already exists for $user."
  fi
}
# Function to set Zsh as the default shell for a user
set_zsh_as_default_shell() {
  local user=$1
  echo "Setting Zsh as the default shell for $user..."
  sudo chsh -s $(which zsh) $user
}
# Install Zsh
install_zsh
# Get the default user
DEFAULT_USER=$(getent passwd | awk -F: '$3 == 1000 {print $1}')
if [ -z "$DEFAULT_USER" ]; then
  echo "Default user not found. Please ensure a user with UID 1000 exists."
  exit 1
fi
# Install Oh My Zsh for the default user
install_oh_my_zsh $DEFAULT_USER || {
  echo "Oh My Zsh installation failed for $DEFAULT_USER"
  exit 1
}
# Install Oh My Zsh for root
install_oh_my_zsh root || {
  echo "Oh My Zsh installation failed for root"
  exit 1
}
# Set Zsh as the default shell for both users
set_zsh_as_default_shell $DEFAULT_USER
set_zsh_as_default_shell root
echo  -e "${GREEN} Zsh Installation and configuration complete!"
# Print instructions for the user
echo -e "${GREEN} Please restart your terminal or run 'exec zsh' to start using Zsh."


## Update and upgrade the system
sudo apt update && sudo apt full-upgrade -y

# Install Additional Packages
sudo apt install -y \
    gnupg2 \
    neofetch \
    zsh \
    git \
    curl \
    pipx \
    Kali-win-kex \
    fzf \
    brave-browser

## Establish pbcopy and pbpaste
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
echo  -e "${GREEN} pbcopy and pbpaste installation complete!"


# Set zsh as the default shell
# chsh -s $(which zsh)

# Clone and install any additional configuration or dotfiles from a repository (optional)
# Uncomment and modify the lines below to fit your repository
# git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
# cp ~/dotfiles/.zshrc ~/.zshrc
# cp ~/dotfiles/.vimrc ~/.vimrc

# Apply changes by sourcing .zshrc and switching to new zsh shell

# Clean Up Packages
sudo apt autoremove -y

## Intall NordVPN
sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)
# nordvpn login
# nordvpn connect



## Installing PipX Apps into opt
cd /opt
git clone https://github.com/danielmiessler/fabric.git



echo  -e "${GREEN} End of Script"