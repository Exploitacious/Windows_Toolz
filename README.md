# System-Debloat
Automated Windows 10 System Debloat Script to get machines ready for business deployment

This powershell script accomplishes the follwoing objectives:

Registry Tweaks
	- Disables Telemetry by Microsoft / Windows
	- Disables Windows Preview Builds
	- Disables Wi-Fi Sense (https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwiy3qmx1MzyAhXURTABHVlSCUIQFnoECAcQAQ&url=https%3A%2F%2Fwww.lifewire.com%2Fwhat-is-wifi-sense-windows-10-4586925&usg=AOvVaw14UdBdVJlIKdrzTSu3c9LN)
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

Windows Appx Bloatware Perma-Uninstall List

	- See "Bloatware" Variable for full list.
	- To add or remove bloatware apps from this list, simply add then in quotes with wildcard * symbols.
	- To make sure they'll be picked up and removed, test them on a machine by running:  get-appxpackage -name *appName*

Per-User first-time logon script to tweak user interface - Coming soon!
	- My goal is to deploy a mini script to run at first-time-logon for each user on the system to tweak the user interface into being nice and clean.
	- Will run as per-user context.
	
	Stay tuned!
