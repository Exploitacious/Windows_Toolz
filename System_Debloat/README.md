# System-Debloat
Automated Windows 10 System Debloat Script to get machines ready for business deployment.
This powershell script accomplishes the follwoing objectives:

# One-Liner to Launch in Powershell or CMD (Run as Admin)
curl -L cleanup.umbrellaitgroup.com -o cleanup.cmd && cleanup.cmd

# Registry Tweaks
- Disables Telemetry by Microsoft / Windows
- Disables Windows Preview Builds
- Disables Wi-Fi Sense
- Disables Bing Search in Start-Menu
- Disables Suggested Applications
- Disables Feedback
- Disables Windows Defender System Tray Icon (Visual Only)
- Disables entire IPv6 stavk
- Enables Windows Update Auto-Downloads
- Enabling Windows Search indexing service
- Enabling Superfetch service
- Enabling and Configuring System Restore for System Drive
- Disable Fast-Startup
- Hiding people icon
- Showing Taskbar Search icon
- Enabling NumLock after startup
- Setting Control Panel view to small icons
- Enabling Clipboard History
- Disabling First Logon Animation
- Disabling Xbox features
- Enabling verbose startup/shutdown status messages
- Showing all tray icons
- Unpinning all Start Menu tiles
- Removing Weather Taskbar Widget (Comment this out for any version previous to 20H2)
- Removing Meet Now Feature

# Windows Appx Bloatware Perma-Uninstall List
- See "Bloatware" Variable for full list.
- To add or remove bloatware apps from this list, simply add then in quotes with wildcard * symbols.
- To make sure they'll be picked up and removed, test them on a machine by running:  get-appxpackage -name *appName*

# Per-User first-time logon script to clean up user interface
- Make sure you download BOTH the FirstLogon.bat file and DebloatScript-HKCU.ps1 into the same directory as the main System Debloat Script.
- A copy of the Bat and HKCU will be placed in C:\Windows\FirstUserLogon and ran every time a user logs in for the FIRST TIME ONLY.
- This 'mini' script cleans up the user interface and removes some of the clutter that Windows 10 likes to throw at you.
