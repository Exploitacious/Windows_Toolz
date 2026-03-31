<#
.SYNOPSIS
    Forcefully stops the process for a given Hyper-V virtual machine.

.DESCRIPTION
    This script prompts the user for the name of a Hyper-V virtual machine. It then identifies the virtual machine's Globally Unique Identifier (GUID) and uses it to find the corresponding Virtual Machine Worker Process (VMWP.exe). Finally, it forcibly terminates this process, which is equivalent to "pulling the plug" on the virtual machine. This should only be used as a last resort when a VM is unresponsive.

.NOTES
    Author: Alex Ivantsov
    Date:   2025-06-11
#>

#---------------------------------------------------------------------------------------------------------------------#
#                                                 USER-DEFINABLE VARIABLES                                            #
#---------------------------------------------------------------------------------------------------------------------#

# Prompt the user to enter the name of the virtual machine they wish to terminate.
$VMName = Read-Host "Enter the name of the virtual machine you wish to forcibly stop"

#---------------------------------------------------------------------------------------------------------------------#
#                                                       FUNCTIONS                                                       #
#---------------------------------------------------------------------------------------------------------------------#

Function Get-VMPowerKill {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$VirtualMachineName
    )

    # Begin the process of stopping the VM.
    Write-Host "Attempting to forcibly stop the virtual machine: $($VirtualMachineName)..."

    try {
        # Retrieve the Virtual Machine object using the provided name.
        # An error will be thrown if the VM is not found.
        $VM = Get-VM -Name $VirtualMachineName -ErrorAction Stop

        # Get the unique identifier (GUID) of the virtual machine.
        $VmGUID = $VM.Id

        # Announce the found GUID to the user.
        Write-Host "Found Virtual Machine GUID: $($VmGUID)"

        # Find the Virtual Machine Worker Process (vmwp.exe) associated with the VM's GUID.
        # This is done by searching through all running processes for one that is named 'vmwp.exe'
        # and has a command line that includes the VM's GUID.
        $VMProcess = Get-WmiObject -Class Win32_Process | Where-Object { $_.Name -like 'vmwp.exe' -and $_.CommandLine -like "*$($VmGUID)*" }

        # Check if a process was found.
        if ($null -ne $VMProcess) {
            # Display the Process ID that is about to be terminated.
            Write-Host "Found VM Worker Process ID: $($VMProcess.ProcessId). Terminating..."

            # Forcibly stop the identified process.
            Stop-Process -Id $VMProcess.ProcessId -Force

            # Confirm that the process has been terminated.
            Write-Host "The process for $($VirtualMachineName) has been successfully terminated." -ForegroundColor Green
        }
        else {
            # Inform the user if no running process could be found for the specified VM.
            Write-Host "Could not find a running worker process for virtual machine '$($VirtualMachineName)'." -ForegroundColor Yellow
        }
    }
    catch [Microsoft.HyperV.PowerShell.VirtualMachineNotFoundException] {
        # Handle the case where the virtual machine name does not exist.
        Write-Error "Error: A virtual machine with the name '$($VirtualMachineName)' was not found."
    }
    catch {
        # Catch any other unexpected errors that may have occurred.
        Write-Error "An unexpected error occurred: $($_.Exception.Message)"
    }
}

#---------------------------------------------------------------------------------------------------------------------#
#                                                    SCRIPT EXECUTION                                                 #
#---------------------------------------------------------------------------------------------------------------------#

# Ensure a VM name was actually entered.
if (-not [string]::IsNullOrWhiteSpace($VMName)) {
    # Call the main function to execute the process termination.
    Get-VMPowerKill -VirtualMachineName $VMName
}
else {
    # Inform the user that they did not enter a valid name.
    Write-Host "No virtual machine name entered. The script will now exit." -ForegroundColor Red
}