# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="jispwoso"

# Completion behavior
HYPHEN_INSENSITIVE="true"
COMPLETION_WAITING_DOTS="true"
ENABLE_CORRECTION="true"

# Auto-update behavior
zstyle ':omz:update' mode auto

# Plugins
plugins=(git)
source $ZSH/oh-my-zsh.sh

# User configuration
export PATH="$PATH:$HOME/.local/bin"

### Aliases
# Shell
alias c="clear"
alias x="exit"
alias e="code -n ~/ ~/.zshrc ~/.config/fastfetch/config.jsonc"
alias r="source ~/.zshrc"
alias vsc="cd /mnt/c/users/Alex/VSCODE"
alias h="history -10"
alias hc="history -c"
alias hg="history | grep "
alias ag="alias | grep "
alias sapu='sudo apt-get update'
alias ls='ls -alFh --color=auto --time-style=long-iso'
alias ll='ls -alFh --color=auto --time-style=long-iso'
alias cd..='cd ..'
alias cd...='cd .. && cd ..'

# Utilities
alias connectnord='sudo /usr/local/bin/launch_nordvpn'
alias gcu="git config user.name \"Alex Ivantsov\" && git config user.email \"alex@ivantsov.tech\""
alias myip='curl -s http://ipecho.net/plain; echo'
alias distro='cat /etc/*-release'
alias rustscan='sudo docker run -it --rm --name rustscan --network host --ulimit nofile=100000:100000 --privileged -v $HOME/.rustscan.toml:/home/rustscan/.rustscan.toml:ro rustscan/rustscan:2.1.1'
# Fastfetch (replaces Neofetch)
fastfetch

# Fabric Bootstrap
if [ -f "$HOME/.config/fabric/fabric-bootstrap.inc" ]; then 
  . "$HOME/.config/fabric/fabric-bootstrap.inc"
fi

# Win Kex Desktop
unalias desktop 2>/dev/null
desktop() {
    echo "[*] Purging zombie KeX sessions..."
    kex --kill >/dev/null 2>&1
    
    # Target VNC/RDP locks specifically, leave WSLg's X0 socket alone
    sudo find /tmp/ -maxdepth 1 -name ".X*-lock" ! -name ".X0-lock" -exec rm -f {} + >/dev/null 2>&1

    echo "[*] Stripping Wayland from DBus environment..."
    systemctl --user unset-environment WAYLAND_DISPLAY
    unset WAYLAND_DISPLAY
    export GDK_BACKEND=x11

    case "$1" in
        "rdp")
            echo "[*] Launching KeX RDP (ESM Mode)..."
            IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
            if [ -z "$IP" ]; then
                echo "[-] Error: No IP address found on eth0."
                return 1
            fi
            kex --esm --ip -s >/dev/null 2>&1 &
            sleep 3
            /mnt/c/Windows/System32/mstsc.exe /v:"${IP}:3390"
            ;;
        "1080")
            echo "[*] Launching KeX VNC (Forced 1920x1080)..."
            kex --win -s --ip -g 1920x1080
            ;;
        *)
            echo "[*] Launching KeX VNC (Standard)..."
            echo "[!] Tip: Press F8 in the viewer to toggle fullscreen and scaling."
            kex --win -s --ip
            ;;
    esac
}

# USB Attach (Launch in PS with "usbipd list" // "usbipd bind --busid 4-1" Then, "usb-attach 4-1" in WSL)
usb-attach() {
    if [ -z "$1" ]; then
        echo "[-] Error: You must provide a bus ID (e.g., usb-attach 4-1)"
        return 1
    fi

    echo "[*] Initializing Linux Virtual USB subsystem..."
    # You MUST load this module or the TCP stream has nowhere to go
    sudo modprobe vhci-hcd

    echo "[*] Querying Windows host for physical LAN IP..."
    WIN_IP=$(powershell.exe -NonInteractive -NoProfile -Command "(Get-NetIPConfiguration | Where-Object { \$_.IPv4DefaultGateway -ne \$null }).IPv4Address.IPAddress" | tr -d '\r' | head -n 1)

    if [ -z "$WIN_IP" ]; then
        echo "[-] Error: Could not resolve Windows host IP."
        return 1
    fi

    echo "[*] Windows Host IP: $WIN_IP"
    
    echo "[*] Verifying Windows Firewall hole..."
    if ! nc -z -w 2 "$WIN_IP" 3240; then
        echo "[-] FATAL: TCP port 3240 is closed on $WIN_IP."
        echo "[-] If you opened the Windows Defender rule, a third-party antivirus (Bitdefender, McAfee) is hijacking the block."
        return 1
    fi

    echo "[+] Firewall open. Pulling USB device $1 across the bridge..."
    sudo usbip attach --remote="${WIN_IP}" --busid="$1"
}