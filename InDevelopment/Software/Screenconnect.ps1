#####
# Deploy Screenconnect via Datto RMM Scripting Engine
# 
# Create a new Screenconnect deployment .MSI URL and add it to the SITE Variable list
# Use Machine Name and set Company Name, make sure to choose MSI link
#####

if (($env:ScreenConnectURL -as [string]).length -gt 0) {
    Write-Host "- Using Using the ScreenConnect Provided URL"
    $varURL = $env:ScreenConnectURL
    $Client = $env:CS_PROFILE_NAME

    Try {
        Invoke-WebRequest -Uri $varURL -OutFile "C:\Temp\Screenconnect\ScreenConnect_$Client.msi"
    }
    catch {
        Write-Host "! Unable to download the Screenconnect Package"
        Write-Warning " Check to make sure you are using TLS1.2 in PowerShell"
    }
    Try {
        msiexec /qn /i "C:\Temp\Screenconnect\ScreenConnect_$Client.msi"
    }
    Catch {
        Write-Host "! Unable to install the Screenconnect Package"
        Write-Warning " Check to make sure the file was downloaded correctly."
    }
    
}
else {
    Write-Host "! ERROR: No URL Provided"
    Write-Warning "  Please re-run this Component with a valid Screenconnect .msi URL."
}