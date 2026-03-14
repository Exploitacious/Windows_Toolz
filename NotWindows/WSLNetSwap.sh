# --- WSL Topology Toggle ---
wsl-net() {
    if [ -z "$1" ]; then
        echo "[-] Error: Specify topology. Usage: wsl-net [nat|bridge]"
        return 1
    fi

    echo "[*] Locating Windows User Profile..."
    # Extract the Windows user path and convert it to a Linux-readable /mnt/c/ path
    WIN_USER=$(powershell.exe -NonInteractive -NoProfile -Command 'Write-Host -NoNewline $env:USERPROFILE' | tr -d '\r')
    WSL_CONF_PATH="$(wslpath "$WIN_USER")/.wslconfig"

    if [ "$1" = "nat" ]; then
        echo "[*] Writing NAT topology to .wslconfig..."
        echo -e "[wsl2]\nnetworkingMode=nat" > "$WSL_CONF_PATH"
    elif [ "$1" = "bridge" ]; then
        echo "[*] Writing Bridged topology to .wslconfig..."
        # Ensure the vmSwitch name matches what you created in Phase 1 exactly
        echo -e "[wsl2]\nnetworkingMode=bridged\nvmSwitch=\"External Switch\"\ndhcp=true\nipv6=true" > "$WSL_CONF_PATH"
    else
        echo "[-] Invalid option. Use 'nat' or 'bridge'."
        return 1
    fi

    echo "[!] Topology staged. Committing hypervisor suicide in 3 seconds..."
    sleep 3
    # Call Windows to execute the kill command on this environment
    powershell.exe -NonInteractive -NoProfile -Command "wsl --shutdown"
}