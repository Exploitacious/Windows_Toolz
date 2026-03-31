<#
.SYNOPSIS
    A PowerShell script to clean up and configure Adobe Acrobat and Reader DC.
.DESCRIPTION
    This script modifies the Windows Registry and system settings to make Adobe Acrobat/Reader
    less intrusive. It accepts the EULA, disables the new UI ("Modern Viewer"), removes AI features,
    disables pop-ups and notifications, and stops unnecessary services and scheduled tasks.
    
    This script must be run with Administrator privileges.
.AUTHOR
    Alex Ivantsov
.DATE
    August 28, 2025
#>

#------------------------------------------------------------------------------------
# SCRIPT CONFIGURATION
#------------------------------------------------------------------------------------
# Add the names of any Adobe-related services you want to disable to this list.
$adobeServicesToDisable = @(
    "AdobeARMservice",      # Adobe Acrobat Update Service
    "AGMService",           # Adobe Genuine Monitor Service
    "AGSService"            # Adobe Genuine Software Integrity Service
)

# Add the names of any Adobe-related scheduled tasks you want to disable to this list.
$adobeTasksToDisable = @(
    "Adobe Acrobat Update Task",
    "AdobeGCInvoker-1.0"
)

#------------------------------------------------------------------------------------
# SCRIPT BODY (Do not edit below this line unless you know what you're doing)
#------------------------------------------------------------------------------------

# Main function to orchestrate all the cleanup operations.
function Start-AdobeCleanup {
    # Verify the script is running with Administrator privileges.
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]'Administrator')) {
        Write-Error "This script requires Administrator privileges. Please re-run it in an elevated PowerShell session."
        # Pause to allow the user to read the error before the window closes.
        if ($Host.Name -eq "ConsoleHost") {
            Read-Host "Press Enter to exit"
        }
        return
    }

    Write-Host "Starting Adobe Cleanup and Configuration..." -ForegroundColor Green
    
    # Apply all registry modifications.
    Configure-AdobeRegistry

    # Disable specified Adobe services.
    Disable-AdobeServices -ServiceNames $adobeServicesToDisable
    
    # Disable specified Adobe scheduled tasks.
    Disable-AdobeScheduledTasks -TaskNames $adobeTasksToDisable

    Write-Host "`nAdobe cleanup process is complete!" -ForegroundColor Green
}

# Function to apply a comprehensive list of registry tweaks.
function Configure-AdobeRegistry {
    Write-Host "`n[+] Applying Registry Tweaks..." -ForegroundColor Cyan

    # An array of hashtables, where each hashtable defines a single registry key to be set.
    # H = Hive (HKLM or HKCU)
    # P = Path (the registry key path without the hive)
    # N = Name (the name of the DWORD value)
    # V = Value (the data for the DWORD value)
    $registryTweaks = @(
        # --- HKLM (Local Machine) Settings - Affects all users ---
        # These settings are applied for BOTH Adobe Reader and Adobe Acrobat Pro.
        
        # Accept End User License Agreement automatically.
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'; N = 'bAcceptEULA'; V = 1 },
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; N = 'bAcceptEULA'; V = 1 },

        # Disable the updater and prevent it from running.
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'; N = 'bUpdater'; V = 0 },
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; N = 'bUpdater'; V = 0 },

        # Disable upsell messages and ads for other Adobe products.
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'; N = 'bAcroSuppressUpsell'; V = 1 },
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; N = 'bAcroSuppressUpsell'; V = 1 },

        # Disable all Generative AI features ("GenTech").
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'; N = 'bEnableGentech'; V = 0 },
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; N = 'bEnableGentech'; V = 0 },

        # Disable Adobe Sign integration features.
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown'; N = 'bToggleAdobeSign'; V = 1 },
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; N = 'bToggleAdobeSign'; V = 1 },

        # Disable all third-party connectors like SharePoint, Dropbox, etc.
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown\cSharePoint'; N = 'bDisableSharePointFeatures'; V = 1 },
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown\cSharePoint'; N = 'bDisableSharePointFeatures'; V = 1 },

        # Hide the "Send for Signature" options.
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown'; N = 'bIsSCReducedModeEnforcedEx'; V = 1 },

        # Disable in-product messaging when viewing a document.
        @{ H = 'HKLM'; P = 'SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown\cIPM'; N = 'bDontShowMsgWhenViewingDoc'; V = 1 },


        # --- HKCU (Current User) Settings - Affects only the current user ---
        
        # *** NEW *** Disable the "New Acrobat" modern UI and revert to the classic interface.
        @{ H = 'HKCU'; P = 'Software\Adobe\Acrobat Reader\DC\AVGeneral'; N = 'bOptOutFromModernViewer'; V = 1 },
        @{ H = 'HKCU'; P = 'Software\Adobe\Adobe Acrobat\DC\AVGeneral'; N = 'bOptOutFromModernViewer'; V = 1 },
        
        # Disable the welcome screen on application startup.
        @{ H = 'HKCU'; P = 'Software\Adobe\Acrobat Reader\DC\AVGeneral'; N = 'bShowWelcomeScreen'; V = 0 },
        @{ H = 'HKCU'; P = 'Software\Adobe\Adobe Acrobat\DC\AVGeneral'; N = 'bShowWelcomeScreen'; V = 0 },
        
        # Prompt the user to set Adobe as the default PDF handler if it isn't already.
        # Note: Modern Windows versions protect file associations, so direct programmatic changes are unreliable.
        # Setting this to 0 ensures Adobe will ask the user, which is the most reliable method.
        @{ H = 'HKCU'; P = 'Software\Adobe\Acrobat Reader\DC\AVAlert\cCheckbox'; N = 'iAppDoNotTakePDFOwnershipAtLaunch'; V = 0 },
        @{ H = 'HKCU'; P = 'Software\Adobe\Adobe Acrobat\DC\AVAlert\cCheckbox'; N = 'iAppDoNotTakePDFOwnershipAtLaunch'; V = 0 },

        # Disable potentially insecure JavaScript execution within PDF files.
        @{ H = 'HKCU'; P = 'Software\Adobe\Acrobat Reader\DC\JSPrefs'; N = 'bEnableJS'; V = 0 },
        @{ H = 'HKCU'; P = 'Software\Adobe\Adobe Acrobat\DC\JSPrefs'; N = 'bEnableJS'; V = 0 },
        
        # Disable in-product messages and upsells in the user profile.
        @{ H = 'HKCU'; P = 'Software\Adobe\Acrobat Reader\DC\IPM'; N = 'bShowProductMessages'; V = 0 },
        @{ H = 'HKCU'; P = 'Software\Adobe\Adobe Acrobat\DC\IPM'; N = 'bShowProductMessages'; V = 0 }
    )

    # Loop through each tweak defined above and apply it using splatting.
    $registryTweaks | ForEach-Object {
        Set-RegistryDwordValue @_
    }
}

# A helper function to create or set a DWORD value in the registry.
function Set-RegistryDwordValue {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('HKLM', 'HKCU')]
        [string]$Hive,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [int]$Value
    )

    # Build the full registry path based on the hive and path provided.
    $fullPath = "$($Hive):\$($Path)"
    
    try {
        # Create the registry path if it does not exist.
        if (-not (Test-Path -Path $fullPath)) {
            New-Item -Path $fullPath -Force -ErrorAction Stop | Out-Null
        }

        # Set the registry value.
        New-ItemProperty -Path $fullPath -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-Host "    Set: '$($fullPath)' -> '$($Name)' = '$($Value)'"
    }
    catch {
        Write-Warning "Failed to set registry value: $($_.Exception.Message)"
    }
}

# Function to stop and disable a list of Windows services.
function Disable-AdobeServices {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ServiceNames
    )

    Write-Host "`n[+] Disabling Services..." -ForegroundColor Cyan

    foreach ($serviceName in $ServiceNames) {
        # Check if the service exists.
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        
        if ($service) {
            try {
                # Stop the service if it's running.
                if ($service.Status -ne 'Stopped') {
                    Stop-Service -Name $service.Name -Force -ErrorAction Stop
                    Write-Host "    Stopped: '$($service.Name)'"
                }
                
                # Disable the service (set StartupType to Disabled).
                if ($service.StartupType -ne 'Disabled') {
                    Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop
                    Write-Host "    Disabled: '$($service.Name)'"
                }
                else {
                    Write-Host "    Already Disabled: '$($service.Name)'"
                }
            }
            catch {
                Write-Warning "Could not stop or disable service '$($serviceName)': $($_.Exception.Message)"
            }
        }
        else {
            Write-Host "    Not Found: Service '$($serviceName)' is not installed."
        }
    }
}

# Function to disable a list of Scheduled Tasks.
function Disable-AdobeScheduledTasks {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$TaskNames
    )

    Write-Host "`n[+] Disabling Scheduled Tasks..." -ForegroundColor Cyan

    foreach ($taskName in $TaskNames) {
        try {
            # Get the task to see if it exists and if it is already disabled.
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            
            if ($task) {
                if ($task.State -ne 'Disabled') {
                    Disable-ScheduledTask -TaskName $task.TaskName -ErrorAction Stop
                    Write-Host "    Disabled: Task '$($taskName)'"
                }
                else {
                    Write-Host "    Already Disabled: Task '$($taskName)'"
                }
            }
            else {
                Write-Host "    Not Found: Task '$($taskName)' does not exist."
            }
        }
        catch {
            Write-Warning "Could not disable scheduled task '$($taskName)': $($_.Exception.Message)"
        }
    }
}

# --- SCRIPT EXECUTION ---
Start-AdobeCleanup