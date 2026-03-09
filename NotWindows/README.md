# Set up my Linux Shell (Kali and Ubuntu)
An interactive provisioning script for deploying a fully configured Linux environment. Optimized for Debian and Kali Linux. 


## Execution
(Use any of the below)

```bash
wget -qO setup.sh [https://shell.ivantsov.tech](https://shell.ivantsov.tech) && sudo bash setup.sh
```
wget -qO setup.sh https://shell.ivantsov.tech && sudo bash setup.sh
```
curl -fsSL https://shell.ivantsov.tech | sudo bash
```

---

## Module Breakdown

The setup is divided into selectable modules via an interactive checklist.

### 1. CORE (System & Repositories)
* Injects trusted GPG keys for the Kali archive and Brave Browser.
* Dynamically maps Brave's stable repository to `sources.list.d`.
* Executes a full `apt update` and `apt full-upgrade`.
* Suppresses the default "Message of the Day" (MOTD) by creating `~/.hushlogin`.

### 2. ZSH (Shell Environment)
* Installs Zsh and Oh My Zsh headlessly for both the `root` and default user profiles.
* Enforces Zsh as the default login shell.
* Applies base Oh My Zsh templates before custom dotfiles overwrite them.

### 3. PKGS (Base Toolchain)
* Installs standard CLI utilities: `fastfetch`, `git`, `curl`, `pipx`, `fzf`, `nmap`, `xclip`, `tmux`, and `ffmpeg`.
* Installs GUI/Desktop tools: `brave-browser` and `kali-win-kex` (for WSL environments).

### 4. CLIP (Clipboard Integration)
* Bridges the gap between macOS muscle memory and Linux.
* Writes `/usr/local/bin/pbcopy` and `pbpaste` wrappers around `xclip` to interact seamlessly with the X11/Wayland clipboard.

### 5. TMUX (Multiplexer)
* Downloads the custom `.tmux.conf` file.
* Headlessly clones the Tmux Plugin Manager (TPM).
* Automatically executes the TPM `install_plugins.sh` script to pull down configured themes and utilities without requiring manual user intervention inside the Tmux session.

### 6. DOCKER (Engine & Compose)
* Installs Docker CE securely via official Docker GPG keys.
* **Kali Intercept:** Automatically detects `kali-rolling` environments and forces `apt` to pull from Docker's `bookworm` (Debian 12) release branch to prevent 404 repository errors.
* Adds the default user to the `docker` group for rootless execution.

### 7. VPN (NordVPN OpenVPN Wrapper)
* Downloads the complete archive of NordVPN `.ovpn` server configurations.
* **Cipher Patching:** Uses `find` and `xargs -0 sed` to batch-process over 5,000 config files during installation, stripping deprecated `AES-256-CBC` ciphers and injecting modern `AES-256-GCM:CHACHA20-POLY1305` parameters.
* Generates a lightweight, secure CLI launcher (`launch_nordvpn`) that handles authentication via an isolated, `chmod 600` credential file.

### 8. RUST (RustScan Container)
* Pulls the `rustscan/rustscan:2.1.1` Docker image. 
* Avoids native cargo installations to bypass host OS file descriptor limitations and dependency bloat.

### 9. DOTS (Configuration Sync)
* Pulls the custom `.zshrc`, `config.jsonc` (Fastfetch), and `core.toml` (RustScan) directly from this repository into their respective `.config` and home directories.

---

## Configuration File Settings

### `.zshrc`
* **Theme:** `jispwoso`
* **Plugins:** `git`
* **Aliases:** * `e`: Opens core configs in VS Code.
    * `rustscan`: Executes the RustScan Docker container with `--network host` to prevent NAT routing failures, and overrides Docker's default ulimit (`--ulimit nofile=100000:100000`) to prevent socket exhaustion during high-speed batch scans.
    * `connectnord`: Executes the custom VPN launcher with sudo privileges.
* **Startup:** Automatically invokes `fastfetch` and sources the Fabric AI bootstrap if present.

### `.tmux.conf`
* **Prefix:** Rebound from `C-b` to `C-Space`.
* **Indexing:** Windows and panes start at `1` instead of `0`.
* **Navigation:** Vi mode keys enabled for buffer traversal.
* **Plugins:** Utilizes `tmux-sensible` for baseline defaults and `catppuccin-tmux` for the status bar theme.
* **Splits:** Bound to `"` and `%`, configured to open new panes in the current working directory (`#{pane_current_path}`).

### `config.jsonc` (Fastfetch)
* **Logo:** Forced to `parabola_small`.
* **Modules:** Minimalist execution displaying only Memory, Disk (Root only), Uptime, Local IP, and Public IP (2000ms timeout threshold).
* **Formatting:** Replaces the standard separator with a colon and a space (`: `).

### `core.toml` (RustScan)
* **Scan Strategy:** SYN scan (`-sS` equivalent) randomized across ports 1-65535.
* **Performance:** Batch size of 10,000 packets with a timeout of 1500ms. Rate limit set to 10,000 packets per second.
* **Nmap Handoff:** Automatically passes discovered open ports to Nmap using the `-sV -sC -O` flags for service enumeration, default scripts, and OS detection.