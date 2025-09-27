# Install or Verify ConnectWise ScreenConnect for Datto RMM

This script automates the installation or verification of a ConnectWise ScreenConnect client on a target device. If the client is missing, it is downloaded, validated, and installed; if present, its existence is confirmed. The script then generates a direct join link and stores it in a specified Datto RMM User Defined Field (UDF).

## How to Use

1.  In your Datto RMM, create a new Component and paste the content of the `.ps1` script.
2.  In the Component settings, create the required variables (see examples below) and fill them with the details from your ScreenConnect instance.
3.  Set the **UDF number** variable (`usrUDF`) to match the Custom Field where you want the join link to be stored.
4.  Run the Component against your target devices as a scheduled job or quick job. The script requires administrative privileges to run.

## Configuration Examples

You must create these variables within the Datto RMM Component configuration. The script will not run without them.

```powershell
# Public key thumbprint from your ScreenConnect instance.
$env:ConnectWiseControlPublicKeyThumbprint = 'PASTE_THUMBPRINT_HERE'

# Full URL to the EXE installer from your ScreenConnect instance.
$env:ConnectWiseControlInstallerUrl = '[https://screenconnect.yourdomain.com/Bin/ScreenConnect.ClientSetup.exe?e=Access&h=...&p=...&k=](https://screenconnect.yourdomain.com/Bin/ScreenConnect.ClientSetup.exe?e=Access&h=...&p=...&k=)...'

# RMM Custom Field (UDF) number to store the final join link.
$env:usrUDF = '1' 

# The expected Subject Name from the installer's digital signature.
$env:ExpectedCertificateSubject = 'CN=DigiCert Trusted G4 Code Signing RSA4096 SHA384 2021 CA1'

# The expected thumbprint from the installer's digital signature.
$env:ExpectedCertificateThumbprint = '7B0F360B775F76C94A12CA48445AA2D2A875701C'