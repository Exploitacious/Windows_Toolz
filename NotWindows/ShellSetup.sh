#!/bin/bash
# Interactive setup script for Debian/Kali environments

# Enforce root execution
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Try: sudo $0"
  exit 1
fi

# Determine default user (first user with UID >= 1000)
DEFAULT_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' | head -n 1)
USER_HOME=$(eval echo ~$DEFAULT_USER)

# Verify whiptail is installed for the interactive menu
if ! command -v whiptail &> /dev/null; then
  apt-get update && apt-get install -y whiptail
fi

# --- FUNCTIONS ---

update_repos_and_system() {
  echo "Updating repositories and system..."
  wget -q https://archive.kali.org/archive-key.asc -O /etc/apt/trusted.gpg.d/kali-archive-keyring.asc || true
  curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | tee /etc/apt/sources.list.d/brave-browser-release.list
  apt-get update && apt-get full-upgrade -y
  touch "$USER_HOME/.hushlogin"
}

install_zsh_env() {
  echo "Installing Zsh and Oh My Zsh..."
  apt-get install -y zsh

  for target_user in "$DEFAULT_USER" "root"; do
    local target_home=$(eval echo ~$target_user)
    if [ ! -d "$target_home/.oh-my-zsh" ]; then
      sudo -u "$target_user" sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh) --unattended"
      cp "$target_home/.oh-my-zsh/templates/zshrc.zsh-template" "$target_home/.zshrc"
      chown "$target_user":"$target_user" "$target_home/.zshrc"
    fi
    chsh -s $(which zsh) "$target_user"
  done
}

install_base_packages() {
  echo "Installing core packages..."
  apt-get install -y gnupg2 fastfetch git curl pipx kali-win-kex fzf brave-browser ffmpeg nmap xclip
}

setup_clipboard_aliases() {
  echo "Creating pbcopy and pbpaste scripts..."
  cat > /usr/local/bin/pbcopy << 'EOF'
#!/bin/bash
xclip -selection clipboard
EOF
  cat > /usr/local/bin/pbpaste << 'EOF'
#!/bin/bash
xclip -selection clipboard -o
EOF
  chmod +x /usr/local/bin/pbcopy /usr/local/bin/pbpaste
}

install_docker_engine() {
  echo "Installing Docker..."
  apt-get install -y ca-certificates curl
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc

  # Dynamically pull the correct OS release info
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $VERSION_CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
  
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  
  usermod -aG docker "$DEFAULT_USER"
  systemctl enable --now docker
}

install_nordvpn() {
  echo "Installing NordVPN..."
  curl -sSf https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/NotWindows/InstallNordVPN.sh | bash || echo "NordVPN install failed."
}

install_rustscan() {
  echo "Pulling RustScan Docker image..."
  docker pull rustscan/rustscan:2.1.1
}

fetch_dotfiles() {
  echo "Pulling custom dotfiles..."
  local ZSHRC_URL="https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/NotWindows/dotFiles/.zshrc"
  local FASTFETCH_URL="https://raw.githubusercontent.com/Exploitacious/Windows_Toolz/main/NotWindows/dotFiles/config.conf"
  
  curl -sSLo /root/.zshrc "$ZSHRC_URL"
  curl -sSLo "$USER_HOME/.zshrc" "$ZSHRC_URL"
  chown "$DEFAULT_USER":"$DEFAULT_USER" "$USER_HOME/.zshrc"

  mkdir -p "$USER_HOME/.config/fastfetch"
  curl -sSLo "$USER_HOME/.config/fastfetch/config.jsonc" "$FASTFETCH_URL"
  chown -R "$DEFAULT_USER":"$DEFAULT_USER" "$USER_HOME/.config/fastfetch"
}

cleanup_system() {
  echo "Cleaning up..."
  apt-get autoremove -y
  apt-get clean
}

# --- INTERACTIVE MENU ---

CHOICES=$(whiptail --title "Linux Environment Setup" --checklist \
"Select the components you want to install (Space to toggle, Enter to confirm):" 22 78 10 \
  "CORE" "Update Repos, System, & Keys" ON \
  "ZSH" "Zsh & Oh-My-Zsh (Root & User)" ON \
  "PKGS" "Fastfetch, Git, Brave, Nmap, etc." ON \
  "CLIP" "xclip, pbcopy, pbpaste" ON \
  "DOCKER" "Docker Engine & Compose" OFF \
  "VPN" "NordVPN Script" OFF \
  "RUST" "RustScan via Docker" OFF \
  "DOTS" "Pull Dotfiles from GitHub" ON 3>&1 1>&2 2>&3)

if [ -z "$CHOICES" ]; then
  echo "Installation cancelled."
  exit 0
fi

# --- EXECUTION ---

if [[ $CHOICES == *"CORE"* ]]; then update_repos_and_system; fi
if [[ $CHOICES == *"ZSH"* ]]; then install_zsh_env; fi
if [[ $CHOICES == *"PKGS"* ]]; then install_base_packages; fi
if [[ $CHOICES == *"CLIP"* ]]; then setup_clipboard_aliases; fi
if [[ $CHOICES == *"DOCKER"* ]]; then install_docker_engine; fi
if [[ $CHOICES == *"VPN"* ]]; then install_nordvpn; fi
if [[ $CHOICES == *"RUST"* ]]; then 
  if ! command -v docker &> /dev/null; then
    echo "Docker is required for RustScan. Skipping."
  else
    install_rustscan
  fi
fi
if [[ $CHOICES == *"DOTS"* ]]; then fetch_dotfiles; fi

cleanup_system

echo -e "\nSetup complete. Restart your terminal or run 'exec zsh' to apply shell changes."
if [[ $CHOICES == *"DOCKER"* ]]; then
  echo "Note: Log out and back in to apply Docker group permissions for $DEFAULT_USER."
fi