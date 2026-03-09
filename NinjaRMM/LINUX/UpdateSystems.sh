#!/bin/bash
# 
## Template for Remediation Components for Datto RMM with Bash
# Original PowerShell Concept by Alex Ivantsov @Exploitacious
# Bash Adaptation for Linux by Gemini

# --- Script Information ---
ScriptName="Linux System Updater"
ScriptType="Remediation"
Date=$(date +"%m/%d/%Y %I:%M:%S %p")

# --- Datto RMM Environment Variables (for local testing) ---
# Un-comment and set these for testing outside of Datto RMM
# export CS_PROFILE_UID="TEST_PROFILE_UID"
# export APIEndpoint="https://your-api-endpoint.com/..."
# export usrUDF="7" # UDF number to write a status summary to

# --- Datto RMM Functions and Variables ---

# Initialize a multi-line string for the diagnostic log
DIAG_LOG=""

# Function to append messages to the diagnostic log
log_diag() {
    # Appends a timestamp and the message to the log
    local message="$1"
    DIAG_LOG+="$(date +"%Y-%m-%d %H:%M:%S") - $message"$'\n'
}

# Function to format and print the final diagnostic output for Datto RMM
write_DRMMDiag() {
    echo ""
    echo "<-Start Diagnostic->"
    # Use printf to handle the multi-line string correctly
    printf '%s' "$DIAG_LOG"
    echo "<-End Diagnostic->"
    echo ""
}

# Generate a random UID for this script execution
ScriptUID=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)

##################################
##################################
######## Start of Script #########

log_diag "Script Type: $ScriptType"
log_diag "Script Name: $ScriptName"
log_diag "Script UID: $ScriptUID"
log_diag "Executed On: $Date"
log_diag "============================================================"

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    log_diag "ERROR: This script must be run with root privileges. Aborting."
    write_DRMMDiag
    exit 1
fi

# Initialize UDF string and other state variables
UDF_STRING=""
UPDATED_PACKAGES_LOG=""
UPDATES_PERFORMED=false

# --- Distribution Detection and Update Logic ---
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    log_diag "Detected Distribution ID: $ID"
    DISTRO=$ID
else
    log_diag "WARNING: /etc/os-release not found. Cannot determine distribution."
    DISTRO="unknown"
fi

case $DISTRO in
    ubuntu|debian)
        log_diag "Detected Debian-based system. Using APT."
        export DEBIAN_FRONTEND=noninteractive # Prevents prompts during upgrades
        
        log_diag "Updating package lists (apt-get update)..."
        apt-get update -y > /dev/null 2>&1
        
        log_diag "Checking for upgradable packages..."
        UPGRADABLE_PACKAGES=$(apt list --upgradable 2>/dev/null | grep -v "Listing...")
        
        if [ -n "$UPGRADABLE_PACKAGES" ]; then
            UPDATES_PERFORMED=true
            log_diag "The following packages will be upgraded:"
            UPDATED_PACKAGES_LOG+=$UPGRADABLE_PACKAGES$'\n'
            
            log_diag "Performing system upgrade (apt-get upgrade)..."
            UPGRADE_OUTPUT=$(apt-get upgrade -y --with-new-pkgs 2>&1)
            log_diag "APT upgrade command executed."
            # Append a summary of the upgrade action to the detailed log
            UPDATED_PACKAGES_LOG+=$'\n'"--- APT Upgrade Summary ---"$'\n'$(echo "$UPGRADE_OUTPUT" | grep -E "upgraded, .* newly installed, .* to remove")
        else
            log_diag "No packages to upgrade. System is up to date."
        fi
        
        log_diag "Cleaning up unused packages (autoremove)..."
        apt-get autoremove -y > /dev/null 2>&1
        log_diag "Cleaning up APT cache..."
        apt-get clean > /dev/null 2>&1
        ;;

    centos|rhel|fedora|rocky|almalinux)
        log_diag "Detected RHEL-based system. Using DNF/YUM."
        
        PKG_MANAGER="dnf"
        if ! command -v dnf &> /dev/null; then
            PKG_MANAGER="yum"
        fi
        log_diag "Using package manager: $PKG_MANAGER"
        
        log_diag "Checking for updates..."
        # Running the check-update command just to see what's available
        $PKG_MANAGER check-update > /dev/null 2>&1
        
        if [ $? -eq 100 ]; then # Exit code 100 means updates are available
            UPDATES_PERFORMED=true
            log_diag "Updates are available. Performing system upgrade..."
            # Capture the installed/updated packages from the transaction
            UPGRADE_OUTPUT=$($PKG_MANAGER upgrade -y 2>&1)
            UPDATED_PACKAGES_LOG+=$(echo "$UPGRADE_OUTPUT" | grep -E "Installing:|Upgrading:|Installed:|Updated:")
            log_diag "$PKG_MANAGER upgrade command executed."
        else
            log_diag "No packages to upgrade. System is up to date."
        fi

        log_diag "Cleaning up unused packages (autoremove)..."
        $PKG_MANAGER autoremove -y > /dev/null 2>&1
        log_diag "Cleaning up $PKG_MANAGER cache..."
        $PKG_MANAGER clean all > /dev/null 2>&1
        ;;

    *)
        log_diag "Unsupported Linux distribution: '$DISTRO'."
        UPDATED_PACKAGES_LOG="Unsupported distribution. No updates performed."
        UDF_STRING="Unsupported distro: $DISTRO"
        ;;
esac

# --- Post-Update Checks and Reporting ---
log_diag "============================================================"
log_diag "Update Summary:"
if [ "$UPDATES_PERFORMED" = true ]; then
    log_diag "System updates were applied."
    # Add the detailed log of what was updated
    DIAG_LOG+=$'\n'"--- Updated Packages Details ---"$'\n'$UPDATED_PACKAGES_LOG$'\n'
    UDF_STRING="System updated on $Date."
else
    log_diag "System was already up to date. No updates applied."
    UDF_STRING="System up-to-date as of $Date."
fi

# Check if a reboot is required (a critical maintenance step)
log_diag "Checking if a reboot is required..."
if [ -f /var/run/reboot-required ]; then
    log_diag "✅ REBOOT REQUIRED: A reboot is necessary to apply kernel or other core system updates."
    UDF_STRING+=" Reboot Required."
else
    log_diag "✅ NO REBOOT REQUIRED: System is ready for use."
    UDF_STRING+=" No reboot needed."
fi
log_diag "============================================================"


######## End of Script ###########
##################################
##################################

### Write to UDF if usrUDF (Write To) Number is defined. (Optional)
if [[ -n "$usrUDF" && -n "$UDF_STRING" ]]; then
    log_diag "Preparing to write to UDF $usrUDF."
    TRUNCATED_UDF_STRING=$(echo "$UDF_STRING" | cut -c 1-255) # UDFs are limited to 255 chars
    log_diag "UDF String: $TRUNCATED_UDF_STRING"
    
    # The command to set a UDF on Linux is typically via the 'cag-agent-config' tool.
    # This is the safest way to interact with the agent's configuration.
    AGENT_CONFIG_TOOL="/opt/CentraStage/cag-agent-config"
    if [ -f "$AGENT_CONFIG_TOOL" ]; then
        log_diag "Attempting to write to UDF using $AGENT_CONFIG_TOOL..."
        # NOTE: Un-comment the following line in the Datto RMM component editor to enable this functionality.
        # sudo $AGENT_CONFIG_TOOL --set custom${usrUDF} "${TRUNCATED_UDF_STRING}"
        log_diag "UDF write command is currently commented out for safety. Please test and enable if desired."
    else
        log_diag "WARNING: Agent config tool ($AGENT_CONFIG_TOOL) not found. Cannot write to UDF."
    fi
fi

### Info to be sent to into JSON POST to API Endpoint (Optional)
if [ -n "$APIEndpoint" ]; then
    log_diag "Sending results to API Endpoint."
    
    # Escape the diagnostic log for use in a JSON string
    JSON_DIAG_LOG=$(echo "$DIAG_LOG" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\n/g')
    
    # Create JSON payload using a Here Document
    JSON_PAYLOAD=$(cat <<EOF
{
    "CS_PROFILE_UID": "${CS_PROFILE_UID:-"NOT_SET"}",
    "Script_Diag": "${JSON_DIAG_LOG}",
    "Script_UID": "${ScriptUID}"
}
EOF
)
    
    # Send the request using cURL
    curl -s -X POST -H "Content-Type: application/json" -d "$JSON_PAYLOAD" "$APIEndpoint"
    if [ $? -eq 0 ]; then
        log_diag "API POST request sent successfully."
    else
        log_diag "API POST request failed."
    fi
fi

#######################################################################
### Exit script with proper Datto diagnostic and API Results.
write_DRMMDiag
Exit 0