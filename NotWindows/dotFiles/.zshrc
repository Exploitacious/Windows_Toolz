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
alias desktop='kex --win -s'
alias gcu="git config user.name \"Alex Ivantsov\" && git config user.email \"alex@ivantsov.tech\""
alias myip='curl -s http://ipecho.net/plain; echo'
alias distro='cat /etc/*-release'
alias rustscan='sudo docker run -it --rm --name rustscan --network host --ulimit nofile=100000:100000 --privileged -v /dev:/dev -v $HOME/.rustscan.toml:/root/.rustscan.toml:ro rustscan/rustscan:2.1.1'
# Fastfetch (replaces Neofetch)
fastfetch

# Fabric Bootstrap
if [ -f "$HOME/.config/fabric/fabric-bootstrap.inc" ]; then 
  . "$HOME/.config/fabric/fabric-bootstrap.inc"
fi