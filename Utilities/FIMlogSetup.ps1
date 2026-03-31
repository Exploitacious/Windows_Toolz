<#
.SYNOPSIS
    Configures advanced audit policies for file system access and applies a specific
    System Access Control List (SACL) to designated folders to track changes.

.DESCRIPTION
    This script performs the following actions:
    1. Sets up a logging directory for the script's actions.
    2. Captures the state of the system's audit policy before making changes.
    3. Enables specific 'Object Access' audit policies required for detailed file and folder tracking.
    4. Captures the state of the audit policy after making changes for verification.
    5. Applies a new audit rule to one or more specified folders to log successful attempts
       to delete, change permissions, or take ownership.

.NOTES
    Author:      Alex Ivantsov
    Date:        10/06/2025
    Version:     1.0
    PS Version:  5.1
#>

#------------------------------------------------------------------------------------#
#                                                                                    #
#                           USER-CONFIGURABLE VARIABLES                              #
#      Adjust the variables in this section to match your environment and needs.     #
#                                                                                    #
#------------------------------------------------------------------------------------#

# Specify the base path for this script's log files.
$ScriptLogPath = "C:\Audits\Logs"

# Define the folder(s) you wish to apply the audit settings to.
# To add more folders, separate them with a comma, e.g., @("C:\Data\Finance", "C:\Data\HR")
$TargetFoldersToAudit = @(
    "C:\Users"
)

# Define the user or group whose actions you want to audit. 'Everyone' is a common choice for broad monitoring.
$AuditUserAccount = "Everyone"

# Define the specific file system actions to monitor.
# For a full list of possible values, see the FileSystemRights documentation.
# Example: "Delete,DeleteSubdirectoriesAndFiles,ChangePermissions,Takeownership"
$AuditFileSystemRights = "Delete,DeleteSubdirectoriesAndFiles,ChangePermissions,TakeOwnership"

# Specify whether to audit 'Success', 'Failure', or 'All' types of access attempts.
$AuditAccessType = "Success"

# Define how the audit rule should be inherited by child objects.
# Common values are "ContainerInherit,ObjectInherit" to apply the rule to subfolders and files.
$InheritanceFlags = "ContainerInherit,ObjectInherit"

#------------------------------------------------------------------------------------#
#                                                                                    #
#                                     FUNCTIONS                                      #
#      The following functions handle the core logic of the script. Do not modify.   #
#                                                                                    #
#------------------------------------------------------------------------------------#

Function Initialize-ScriptEnvironment {
    <#
    .SYNOPSIS
        Creates the necessary directory for storing audit policy log files.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    Write-Host "Initializing script environment..." -ForegroundColor Green
    
    # Check if the log directory already exists.
    if (-not (Test-Path -Path $Path -PathType Container)) {
        Write-Host "Log directory not found. Creating directory at '$Path'."
        try {
            # Create the directory. The -Force switch will create parent directories if needed.
            New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
            Write-Host "Successfully created log directory." -ForegroundColor Cyan
        }
        catch {
            # If directory creation fails, display the error and exit the script.
            Write-Error "Failed to create directory at '$Path'. Error: $($_.Exception.Message)"
            exit 1
        }
    }
    else {
        Write-Host "Log directory already exists at '$Path'."
    }
}

Function Get-AuditPolicyState {
    <#
    .SYNOPSIS
        Uses auditpol.exe to export the current advanced audit policy configuration to a file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$OutputFile
    )

    Write-Host "Exporting current audit policy to '$OutputFile'..."
    try {
        # Execute the command-line tool to get all audit policy categories.
        auditpol.exe /get /category:* | Out-File -FilePath $OutputFile -Encoding UTF8 -ErrorAction Stop
        Write-Host "Audit policy export complete." -ForegroundColor Cyan
    }
    catch {
        Write-Error "Failed to export audit policy. Error: $($_.Exception.Message)"
    }
}

Function Configure-AdvancedAuditPolicy {
    <#
    .SYNOPSIS
        Enables specific advanced audit subcategories related to object access.
    #>
    
    Write-Host "Configuring advanced audit policies..." -ForegroundColor Green

    # Array of audit policies to enable for detailed file system monitoring.
    $auditSubcategories = @(
        "Detailed File Share",
        "File Share",
        "File System"
    )

    foreach ($subcategory in $auditSubcategories) {
        Write-Host "Enabling auditing for subcategory: '$subcategory'"
        try {
            # Execute auditpol.exe to set both success and failure auditing for the specified subcategory.
            auditpol.exe /set /subcategory:"$subcategory" /success:enable /failure:enable
        }
        catch {
            Write-Warning "There was an issue setting the audit policy for '$subcategory'."
        }
    }
    Write-Host "Finished configuring advanced audit policies." -ForegroundColor Cyan
}

Function Set-FileSystemAuditRule {
    <#
    .SYNOPSIS
        Applies a new file system audit rule (SACL) to a specified folder.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,

        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Rights,

        [Parameter(Mandatory = $true)]
        [string]$Inheritance,
        
        [Parameter(Mandatory = $true)]
        [string]$AuditType
    )

    Write-Host "Applying audit rule to folder: '$FolderPath'..."

    # Verify the target folder exists before proceeding.
    if (-not (Test-Path -Path $FolderPath -PathType Container)) {
        Write-Warning "Target folder '$FolderPath' does not exist. Skipping."
        return
    }

    try {
        # Retrieve the current Access Control List (ACL) of the target folder.
        $acl = Get-Acl -Path $FolderPath -ErrorAction Stop

        # Create a new FileSystemAuditRule object with the specified parameters.
        # This defines WHAT to audit (Rights), WHO to audit (User), and HOW it applies (Inheritance).
        $auditRule = New-Object System.Security.AccessControl.FileSystemAuditRule(
            $User,
            $Rights,
            $Inheritance,
            "None", # PropagationFlags are typically "None"
            $AuditType
        )

        # Add the newly created audit rule to the ACL object.
        $acl.SetAuditRule($auditRule)

        # Apply the modified ACL back to the folder.
        # The -AclObject parameter is used to pass the entire modified ACL.
        Set-Acl -Path $FolderPath -AclObject $acl -ErrorAction Stop

        Write-Host "Successfully applied audit rule to '$FolderPath'." -ForegroundColor Cyan
    }
    catch {
        # Catch potential errors, such as lack of permissions to modify the ACL.
        Write-Error "Failed to apply audit rule to '$FolderPath'. Error: $($_.Exception.Message)"
    }
}


#------------------------------------------------------------------------------------#
#                                                                                    #
#                                  MAIN EXECUTION                                    #
#         This is the main block that executes the script's logic in order.          #
#                                                                                    #
#------------------------------------------------------------------------------------#

# Announce the start of the script and display the current time.
Write-Host "------------------------------------------------------------"
Write-Host "Advanced Auditing Configuration Script started at $(Get-Date)"
Write-Host "------------------------------------------------------------"

# --- Step 1: Prepare the logging environment ---
Initialize-ScriptEnvironment -Path $ScriptLogPath

# --- Step 2: Capture the 'Before' state of the audit policy ---
Get-AuditPolicyState -OutputFile (Join-Path -Path $ScriptLogPath -ChildPath "AdvancedAuditing_Before.log")

# --- Step 3: Enable the necessary advanced auditing policies ---
Configure-AdvancedAuditPolicy

# --- Step 4: Capture the 'After' state for verification ---
Get-AuditPolicyState -OutputFile (Join-Path -Path $ScriptLogPath -ChildPath "AdvancedAuditing_After.log")

# --- Step 5: Apply the audit rule to the target folder(s) ---
Write-Host "Applying file system audit rules to target folders..." -ForegroundColor Green
foreach ($folder in $TargetFoldersToAudit) {
    Set-FileSystemAuditRule -FolderPath $folder -User $AuditUserAccount -Rights $AuditFileSystemRights -Inheritance $InheritanceFlags -AuditType $AuditAccessType
}

# Announce the completion of the script.
Write-Host "------------------------------------------------------------"
Write-Host "Script finished successfully at $(Get-Date)."
Write-Host "Audit policies have been configured. Events will now be logged in the Windows Security Event Log."
Write-Host "------------------------------------------------------------"