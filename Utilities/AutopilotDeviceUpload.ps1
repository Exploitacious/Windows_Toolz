<#
.SYNOPSIS
    Gathers device information for Windows Autopilot registration and can upload it directly to Intune.

.DESCRIPTION
    This script collects hardware details (Serial Number, Hardware Hash, Make, Model) required for Windows Autopilot.
    It can operate in two modes:
    1.  Offline Mode: Gathers information from one or more computers and saves it to a CSV file.
    2.  Online Mode: Connects to Microsoft Graph (Intune) to directly upload device information, monitor the import and sync process, and optionally perform post-import tasks like adding devices to an Azure AD group or assigning a computer name.

.PARAMETER Name
    An array of computer names or IP addresses to gather information from. Defaults to 'localhost'.

.PARAMETER OutputFile
    The path to the CSV file where device information will be saved. If not specified in Offline mode, output is sent to the console.

.PARAMETER GroupTag
    Specifies a Group Tag (Order ID) to be assigned to the Autopilot device.

.PARAMETER AssignedUser
    Specifies the User Principal Name (UPN) of the user to assign to the device.

.PARAMETER Append
    If specified, the script will append to an existing CSV file instead of overwriting it.

.PARAMETER Credential
    Specifies credentials to use when connecting to remote computers.

.PARAMETER Partner
    Formats the output CSV according to the Microsoft Partner Center specification, including manufacturer and model.

.PARAMETER Force
    Forces the script to gather Manufacturer and Model even if the hardware hash is successfully retrieved.

.PARAMETER Online
    A switch to enable Online mode, which connects to Intune to upload device data.

.PARAMETER TenantId
    The Azure AD Tenant ID to connect to in Online mode.

.PARAMETER AppId
    The Application ID for app-based authentication with Microsoft Graph.

.PARAMETER AppSecret
    The Application Secret for app-based authentication.

.PARAMETER AddToGroup
    The display name of the Azure AD group to which the new Autopilot devices will be added.

.PARAMETER AssignedComputerName
    The computer name to assign to the imported devices.

.PARAMETER Assign
    If specified, the script will wait for a deployment profile to be assigned to the imported devices.

.PARAMETER Reboot
    If specified with -Assign, the computer running the script will reboot after profiles are assigned.

.EXAMPLE
    .\Get-WindowsAutopilotInfo.ps1 -OutputFile "C:\Temp\devices.csv" -GroupTag "Kiosk"
    Gathers Autopilot info from the local machine and saves it to a CSV with the Group Tag "Kiosk".

.EXAMPLE
    .\Get-WindowsAutopilotInfo.ps1 -Name "PC01", "PC02" -Credential (Get-Credential) -OutputFile "C:\Temp\new_devices.csv" -Append
    Gathers info from two remote PCs, prompting for credentials, and appends the data to the specified CSV file.

.EXAMPLE
    .\Get-WindowsAutopilotInfo.ps1 -Online -GroupTag "Sales-Dept" -AddToGroup "Autopilot-Sales" -Assign
    Gathers info from the local PC, uploads it to Intune with a Group Tag, adds it to the "Autopilot-Sales" AAD group, and waits for profile assignment.

.NOTES
    Author:     Your Name/Team
    Version:    2.2 (PS 5.1 Corrected Structure)
    Requires:   PowerShell 5.1. Administrator privileges are recommended.
                The 'WindowsAutopilotIntune' and 'AzureAD' modules are required for Online mode and will be installed automatically.
#>
[CmdletBinding(DefaultParameterSetName = 'Default')]
param(
	[Parameter(Mandatory = $False, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Position = 0)]
	[alias("DNSHostName", "ComputerName", "Computer")]
	[String[]] $Name = @("localhost"),

	[Parameter(Mandatory = $False)]
	[String] $OutputFile,

	[Parameter(Mandatory = $False)]
	[String] $GroupTag,

	[Parameter(Mandatory = $False)]
	[String] $AssignedUser,

	[Parameter(Mandatory = $False)]
	[Switch] $Append,

	[Parameter(Mandatory = $False)]
	[System.Management.Automation.PSCredential] $Credential,

	[Parameter(Mandatory = $False)]
	[Switch] $Partner,

	[Parameter(Mandatory = $False)]
	[Switch] $Force,

	[Parameter(Mandatory = $True, ParameterSetName = 'Online')]
	[Switch] $Online,

	[Parameter(Mandatory = $False, ParameterSetName = 'Online')]
	[String] $TenantId,

	[Parameter(Mandatory = $False, ParameterSetName = 'Online')]
	[String] $AppId,

	[Parameter(Mandatory = $False, ParameterSetName = 'Online')]
	[String] $AppSecret,

	[Parameter(Mandatory = $False, ParameterSetName = 'Online')]
	[String] $AddToGroup,

	[Parameter(Mandatory = $False, ParameterSetName = 'Online')]
	[String] $AssignedComputerName,

	[Parameter(Mandatory = $False, ParameterSetName = 'Online')]
	[Switch] $Assign,

	[Parameter(Mandatory = $False, ParameterSetName = 'Online')]
	[Switch] $Reboot
)

Begin {
	#==============================================================================
	# HELPER FUNCTIONS (MUST BE DEFINED WITHIN THE BEGIN BLOCK)
	#==============================================================================

	function Install-RequiredModules {
		param($ModuleName)
        
		Write-Verbose "Checking for module: $ModuleName"
		if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
			Write-Host "Module '$ModuleName' not found. Attempting to install..."
			try {
				Install-Module $ModuleName -Force -AllowClobber -Scope CurrentUser
			}
			catch {
				Write-Error "Failed to install module '$ModuleName'. Please install it manually and try again." -ErrorAction Stop
			}
		}
		Import-Module $ModuleName -Scope Global
	}

	function Initialize-OnlineSession {
		# Ensure NuGet provider is available
		if (-not (Get-PackageProvider -Name 'NuGet' -ErrorAction SilentlyContinue)) {
			Write-Host "Installing required package provider: NuGet."
			Install-PackageProvider -Name 'NuGet' -Force -Scope CurrentUser
		}

		# Install and import required modules
		Install-RequiredModules -ModuleName 'WindowsAutopilotIntune'
		if ($AddToGroup) {
			Install-RequiredModules -ModuleName 'AzureAD'
		}

		# Connect to Microsoft Graph
		try {
			if ($AppId) {
				Write-Host "Connecting to Intune via App-based authentication..."
				Connect-MSGraphApp -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret
			}
			else {
				Write-Host "Connecting to Intune via interactive login..."
				$graphConnection = Connect-MSGraph
				Write-Host "Successfully connected to Intune tenant: $($graphConnection.TenantId)"
				if ($AddToGroup) {
					Connect-AzureAD -AccountId $graphConnection.UPN
				}
			}
		}
		catch {
			Write-Error "Failed to connect to Microsoft Graph. Please check credentials and permissions." -ErrorAction Stop
		}
	}

	function Wait-AndReportProgress {
		param(
			[string]$ActivityName,
			[scriptblock]$CheckAction,
			[int]$DeviceCount
		)
        
		$processingCount = 1
		while ($processingCount -gt 0) {
			$processingCount = & $CheckAction
			Write-Host "Waiting for $ActivityName... ($processingCount of $DeviceCount devices remaining)"
			if ($processingCount -gt 0) {
				Start-Sleep -Seconds 15
			}
		}
		Write-Host "$ActivityName completed for all devices."
	}

	#==============================================================================
	# BEGIN BLOCK INITIALIZATION
	#==============================================================================
    
	$Global:collectedComputers = New-Object -TypeName 'System.Collections.Generic.List[psobject]'

	if ($Online.IsPresent) {
		Initialize-OnlineSession
		# In Online mode, a CSV file is used to stage data. If not provided, create a temporary one.
		if (-not $PSBoundParameters.ContainsKey('OutputFile')) {
			$script:OutputFile = Join-Path -Path $env:TEMP -ChildPath "autopilot-upload-$(Get-Date -Format 'yyyyMMddHHmmss').csv"
			Write-Verbose "Online mode enabled. Using temporary output file: $script:OutputFile"
		}
	}
}

Process {
	foreach ($comp in $Name) {
		$cimSession = $null
		try {
			Write-Verbose "Attempting to connect to computer: $comp"
			$CimParams = @{ ComputerName = $comp }
			if ($PSBoundParameters.ContainsKey('Credential')) {
				$CimParams.Credential = $Credential
			}
			$cimSession = New-CimSession @CimParams

			# --- Gather Device Information ---
			Write-Verbose "Gathering BIOS information from $comp..."
			$serialNumber = (Get-CimInstance -CimSession $cimSession -ClassName 'Win32_BIOS').SerialNumber

			Write-Verbose "Gathering Autopilot hardware hash from $comp..."
			$devDetail = Get-CimInstance -CimSession $cimSession -Namespace 'root/cimv2/mdm/dmmap' -ClassName 'MDM_DevDetail_Ext01' -Filter "InstanceID='Ext' AND ParentID='./DevDetail'" -ErrorAction SilentlyContinue
            
			$hardwareHash = ""
			if ($devDetail -and (-not $Force)) { $hardwareHash = $devDetail.DeviceHardwareData }

			# --- Build Output Object ---
			$deviceObjectProperties = [ordered]@{
				"Device Serial Number" = $serialNumber
				"Windows Product ID"   = "" # This value is generally not needed.
				"Hardware Hash"        = $hardwareHash
			}

			if (-not $hardwareHash -or $Force -or $Partner) {
				Write-Verbose "Hardware hash not found or gathering was forced. Getting make and model."
				$cs = Get-CimInstance -CimSession $cimSession -Class Win32_ComputerSystem
				$deviceObjectProperties.'Manufacturer name' = $cs.Manufacturer.Trim()
				$deviceObjectProperties.'Device model' = $cs.Model.Trim()
			}
            
			if ($GroupTag) { $deviceObjectProperties.'Group Tag' = $GroupTag }
			if ($AssignedUser) { $deviceObjectProperties.'Assigned User' = $AssignedUser }

			$deviceObject = New-Object -TypeName PSObject -Property $deviceObjectProperties
            
			# --- Validate and Add to Collection ---
			if (-not $hardwareHash -and -not $Partner) {
				Write-Warning "Unable to retrieve device hardware data (hash) from computer '$comp'. This device cannot be imported."
			}
			else {
				$Global:collectedComputers.Add($deviceObject)
				Write-Host "Successfully gathered details for device with serial number: $serialNumber"
			}
		}
		catch {
			Write-Error "Failed to process computer '$comp'. Error: $($_.Exception.Message)"
		}
		finally {
			if ($cimSession) {
				Remove-CimSession $cimSession
			}
		}
	}
}

End {
	if ($Global:collectedComputers.Count -eq 0) {
		Write-Warning "No device information was collected. Exiting."
		return
	}
    
	# --- Handle CSV File Output ---
	if ($PSBoundParameters.ContainsKey('OutputFile')) {
		Write-Verbose "Processing output file: $OutputFile"
		$finalComputerList = New-Object -TypeName 'System.Collections.Generic.List[psobject]'
		$finalComputerList.AddRange($Global:collectedComputers)

		if ($Append.IsPresent -and (Test-Path $OutputFile)) {
			Write-Verbose "Append switch is present. Importing existing records from $OutputFile"
			$existingData = Import-Csv -Path $OutputFile
			$finalComputerList.AddRange($existingData)
		}
        
		$finalComputerList | Export-Csv -Path $OutputFile -NoTypeInformation -Encoding UTF8
		Write-Host "Device information written to $OutputFile"
	}
	elseif (-not $Online.IsPresent) {
		# If not writing to file and not in Online mode, output objects to the console.
		$Global:collectedComputers
	}
    
	# --- Handle Online Operations ---
	if ($Online.IsPresent) {
		Write-Host "`n--- Starting Autopilot Online Import ---"
        
		# 1. Import Devices
		$importedDevices = @()
		foreach ($device in $Global:collectedComputers) {
			$importParams = @{
				serialNumber       = $device.'Device Serial Number'
				hardwareIdentifier = $device.'Hardware Hash'
			}
			if ($device.'Group Tag') { $importParams.groupTag = $device.'Group Tag' }
			if ($device.'Assigned User') { $importParams.assignedUser = $device.'Assigned User' }

			$importedDevices += Add-AutopilotImportedDevice @importParams
		}
		$deviceCount = $importedDevices.Count
		Write-Host "Submitted $deviceCount devices for import."

		# 2. Wait for Import to Complete
		$importedDevicesState = $importedDevices # This will hold the latest state of the imported devices.
		Wait-AndReportProgress -ActivityName "device import" -DeviceCount $deviceCount -CheckAction {
			$pending = 0
			$tempState = @()
			foreach ($device in $importedDevicesState) {
				$currentState = Get-AutopilotImportedDevice -id $device.id
				if ($currentState.state.deviceImportStatus -eq "unknown") {
					$pending++
				}
				$tempState += $currentState
			}
			$script:importedDevicesState = $tempState
			return $pending
		}

		# 3. Wait for Sync to Autopilot Records
		$autopilotDevices = @() # This will hold the final Autopilot device objects.
		Wait-AndReportProgress -ActivityName "Intune sync" -DeviceCount $deviceCount -CheckAction {
			$pending = 0
			$tempDevices = @()
			foreach ($device in $importedDevicesState) {
				if ($device.state.deviceImportStatus -eq "complete") {
					$adDevice = Get-AutopilotDevice -id $device.state.deviceRegistrationId -ErrorAction SilentlyContinue
					if (-not $adDevice) {
						$pending++
					}
					$tempDevices += $adDevice
				}
			}
			$script:autopilotDevices = $tempDevices
			return $pending
		}

		# 4. Add to Azure AD Group
		if ($AddToGroup) {
			$aadGroup = Get-AzureADGroup -Filter "DisplayName eq '$AddToGroup'" -ErrorAction SilentlyContinue
			if ($aadGroup) {
				Write-Host "Adding devices to Azure AD group: $AddToGroup"
				foreach ($device in $autopilotDevices) {
					Add-AzureADGroupMember -ObjectId $aadGroup.ObjectId -RefObjectId $device.azureActiveDirectoryDeviceId
				}
			}
			else { Write-Warning "Could not find Azure AD Group '$AddToGroup'. Skipping." }
		}

		# 5. Set Assigned Computer Name
		if ($AssignedComputerName) {
			Write-Host "Setting assigned computer name to: $AssignedComputerName"
			foreach ($device in $autopilotDevices) {
				Set-AutopilotDevice -Id $device.Id -displayName $AssignedComputerName
			}
		}

		# 6. Wait for Profile Assignment
		if ($Assign.IsPresent) {
			Wait-AndReportProgress -ActivityName "profile assignment" -DeviceCount $deviceCount -CheckAction {
				$pending = 0
				foreach ($device in $autopilotDevices) {
					$checkDevice = Get-AutopilotDevice -id $device.id
					if ($checkDevice.deploymentProfileAssignmentStatus -ne "assigned") {
						$pending++
					}
				}
				return $pending
			}
		}
        
		# 7. Final Actions (Reboot, Cleanup)
		if ($Reboot.IsPresent -and $Assign.IsPresent) {
			Write-Host "Profile assignment complete. Rebooting computer."
			Restart-Computer -Force
		}

		if (-not $PSBoundParameters.ContainsKey('OutputFile')) {
			Remove-Item -Path $script:OutputFile -Force -ErrorAction SilentlyContinue
		}
	}
}