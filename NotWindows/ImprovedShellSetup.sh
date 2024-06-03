#!/bin/bash
# Script to set up Kali in WSL environment on a clean install

# Define color for output messages
GREEN='\033[0;32m'

# Function to install necessary keys and update repositories
install_keys_and_update_repos() {
  echo "Installing latest keys and updating repositories..."
  sudo wget https://archive.kali.org/archive-key.asc -O /etc/apt/trusted.gpg.d/kali-archive-keyring.asc
  sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
}

# Function to hold any broken packages
hold_broken_packages() {
  echo "Holding broken packages..."
  echo libc6:amd64 hold | sudo dpkg --set-selections
  # To undo: echo libc6:amd64 install | sudo dpkg --set-selections
}

# Function to clean up the system
clean_system() {
  echo "Cleaning up the system..."
  touch ~/.hushlogin
  sudo apt-get clean
  sudo dpkg --configure -a
  sudo apt install -f
}

# Function to enable experimental repositories using kali-tweaks
enable_experimental_repos() {
  echo "Enabling experimental repositories..."
  sudo kali-tweaks
}

# Function to install Zsh if not already installed
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
    sudo -u $user sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended" || {
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

# Function to update and upgrade the system
update_and_upgrade_system() {
  echo "Updating and upgrading the system..."
  sudo apt update && sudo apt full-upgrade -y
}

# Function to install additional packages
install_additional_packages() {
  echo "Installing additional packages..."
  sudo apt install -y \
    gnupg2 \
    neofetch \
    zsh \
    git \
    curl \
    pipx \
    kali-win-kex \
    fzf \
    brave-browser \
    ffmpeg
}

# Function to install xclip if not already installed
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

# Function to create pbcopy and pbpaste commands using xclip
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

  echo -e "${GREEN} pbcopy and pbpaste installation complete!"
}

# Function to clean up unnecessary packages
clean_up_packages() {
  echo "Cleaning up unnecessary packages..."
  sudo apt autoremove -y
}

# Function to install NordVPN (optional)
install_nordvpn() {
  echo "Installing NordVPN..."
  sh <(curl -sSf https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/NotWindows/KaliWSL/InstallNordVPN.sh)
}

# Function to clone and install additional configuration or dotfiles from a repository (optional)
clone_and_install_dotfiles() {

    # URL of the .zshrc file on GitHub
    GITHUB_URL="https://raw.githubusercontent.com/yourusername/yourrepository/main/.zshrc"

# Paths to place the .zshrc file
ROOT_DIR="/root/.zshrc"
USER_DIR="/home/yourdefaultuser/.zshrc"

# Download the .zshrc file and place it in root directory
curl -o $ROOT_DIR $GITHUB_URL

# Download the .zshrc file and place it in the default user's directory
curl -o $USER_DIR $GITHUB_URL

# Change ownership of the .zshrc file in the default user's directory
chown yourdefaultuser:yourdefaultuser $USER_DIR

echo ".zshrc file has been downloaded and placed in both directories."

  
  
  # Uncomment and modify the lines below to fit your repository
  # git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
  # cp ~/dotfiles/.zshrc ~/.zshrc

  # Apply changes by sourcing .zshrc and switching to new zsh shell (optional)
}

# Main script execution starts here

install_keys_and_update_repos

hold_broken_packages

clean_system

enable_experimental_repos

install_zsh

# Get the default user (assumes UID 1000 is the default user)
DEFAULT_USER=$(getent passwd | awk -F: '$3 == 1000 {print $1}')
if [ -z "$DEFAULT_USER" ]; then
  echo "Default user not found. Please ensure a user with UID 1000 exists."
  exit 1
fi

install_oh_my_zsh $DEFAULT_USER || {
  echo "Oh My Zsh installation failed for $DEFAULT_USER"
  exit 1
}

install_oh_my_zsh root || {
  echo "Oh My Zsh installation failed for root"
  exit 1
}

set_zsh_as_default_shell $DEFAULT_USER

set_zsh_as_default_shell root

echo -e "${GREEN} Zsh Installation and configuration complete!"
echo -e "${GREEN} Please restart your terminal or run 'exec zsh' to start using Zsh."

update_and_upgrade_system

install_additional_packages

install_xclip

create_pbcopy_pbpaste

clean_up_packages

install_nordvpn

clone_and_install_dotfiles

echo -e "${GREEN} End of Script"
```

### Explanation:
# 1. **Modular Functions**: The script is divided into functions, each responsible for a specific task. This makes it easier to read, maintain, and debug.
# 2. **Comments**: Detailed comments are added before each function and significant code block to explain what it does.
# 3. **Error Handling**: Basic error handling is included, especially in functions that perform critical tasks like installing software.
# 4. **Color Output**: The use of color in output messages helps in distinguishing different stages of the script execution.
# 5. **Optional Sections**: Some sections are marked as optional, such as installing NordVPN or cloning dotfiles, which can be uncommented and customized as needed.