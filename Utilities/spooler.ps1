# Set service to Automatic and Start it
Set-Service Spooler -StartupType Automatic
Start-Service Spooler

# Verify it is now running
Get-Service Spooler