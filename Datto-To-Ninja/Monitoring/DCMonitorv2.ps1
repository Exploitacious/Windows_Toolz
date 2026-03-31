$varSHA1_DCD = "2550EC5AFB13F10B5C7CBCE707E0406FDC3C6472"
$varVBBuild = 3

#multilingual DCDiag monitor :: based on a partner submission c. 2015 :: powershell addition edition build 9/seagull

function getProxyData {
    if (([IntPtr]::size) -eq 4) { $configLoc = "$env:SystemDrive\Program Files\CentraStage\CagService.exe.config" } else { $configLoc = "$env:SystemDrive\Program Files (x86)\CentraStage\CagService.exe.config" }
    [xml]$varPlatXML = get-content "$configLoc" -ErrorAction SilentlyContinue
    $script:varProxyLoc = ($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | Where-Object { $_.Name -eq 'ProxyIp' }).value
    $script:varProxyPort = ($varPlatXML.configuration.applicationSettings."CentraStage.Cag.Core.AppSettings".setting | Where-Object { $_.Name -eq 'ProxyPort' }).value
}

function downloadFile {
    #downloadFile build 31/seagull :: copyright datto, inc.

    param (
        [parameter(mandatory = $false)]$url,
        [parameter(mandatory = $false)]$whitelist,
        [parameter(mandatory = $false)]$filename,
        [parameter(mandatory = $false, ValueFromPipeline = $true)]$pipe
    )

    function setUserAgent {
        $script:WebClient = New-Object System.Net.WebClient
        $script:webClient.UseDefaultCredentials = $true
        $script:webClient.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")
        $script:webClient.Headers.Add([System.Net.HttpRequestHeader]::UserAgent, 'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705;)');
    }

    if (!$url) { $url = $pipe }
    if (!$whitelist) { $whitelist = "the required web addresses." }
    if (!$filename) { $filename = $url.split('/')[-1] }
	
    try {
        #enable TLS 1.2
        [Net.ServicePointManager]::SecurityProtocol = [Enum]::ToObject([Net.SecurityProtocolType], 3072)
    }
    catch [system.exception] {
        write-host "- ERROR: Could not implement TLS 1.2 Support."
        write-host "  This can occur on Windows 7 devices lacking Service Pack 1."
        write-host "  Please install that before proceeding."
        exit 1
    }
	
    write-host "- Downloading: $url"
    if ($env:CS_PROFILE_PROXY_TYPE -eq "0" -or !$env:CS_PROFILE_PROXY_TYPE) { $useProxy = $false } else { $useProxy = $true }

    if ($useProxy) {
        setUserAgent
        getProxyData
        write-host ": Proxy location: $script:varProxyLoc`:$script:varProxyPort"
        $script:WebClient.Proxy = New-Object System.Net.WebProxy("$script:varProxyLoc`:$script:varProxyPort", $true)
        $script:WebClient.DownloadFile("$url", "$filename")
        if (!(test-path $filename)) { $useProxy = $false }
    }

    if (!$useProxy) {
        setUserAgent #do it again so we can fallback if proxy fails
        $script:webClient.DownloadFile("$url", "$filename")
    } 

    if (!(test-path $filename)) {
        write-host "- ERROR: File $filename could not be downloaded."
        write-host "  Please ensure you are whitelisting $whitelist."
        write-host "- Operations cannot continue; exiting."
        exit 1
    }
    else {
        write-host "- Downloaded:  $filename"
    }
}

function postAlert ($message) {
    write-host '<-Start Result->'
    write-host "X=$message"
    write-host '<-End Result->'
}

function toSHA1Compare {
    #custom build
    param (
        [parameter(mandatory = $true, ValueFromPipeline = $true)]$pipe,
        [parameter(mandatory = $false)]$liveHash
    )

    if ($liveHash) {
        $localHash = [System.BitConverter]::ToString((New-Object System.Security.Cryptography.SHA1CryptoServiceProvider).ComputeHash([System.IO.File]::ReadAllBytes("$pipe"))).Replace("-", "")
        if ($liveHash -ne $localHash) {
            postAlert "ERROR! Hash mismatch. Please report this issue."
            remove-item "$pipe" -Force
            exit 1
        }
        else {
            write-host ": Local and live SHA-1 filehashes match ($liveHash)."
        }
    }
    else {
        [System.BitConverter]::ToString((New-Object System.Security.Cryptography.SHA1CryptoServiceProvider).ComputeHash([System.IO.File]::ReadAllBytes("$pipe"))).Replace("-", "")
    }
}

####################################################################################################################################################

#download/verify/extract
if (!(test-path "$env:ProgramData\CentraStage\Packages\DCDiag\archive.exe" -ErrorAction SilentlyContinue)) {
    new-item -Path "$env:ProgramData\CentraStage\Packages\DCDiag" -ItemType Directory -ErrorAction SilentlyContinue
    "https://storage.centrastage.net/dcdiag/dcdiag-english.exe" | downloadFile -filename "archive.exe"
    move-item archive.exe "$env:ProgramData\CentraStage\Packages\DCDiag\archive.exe"
    "$env:ProgramData\CentraStage\Packages\DCDiag\archive.exe" | toSHA1Compare -liveHash $varSHA1_7z
    cmd /c "$env:ProgramData\CentraStage\Packages\DCDiag\archive.exe -y -o$env:ProgramData\CentraStage\Packages\DCDiag"
}

$varVB = @"
'edited by seagull; august '21 for datto RMM/build 3

'Sets up exit codes for CS
Const intOK = 0
Const intCritical = 1

Dim cmd
dim hostname
'State of Checks ( OK, or CRITICAL)
Dim services : services = "CRITICAL" 
Dim replications : replications = "CRITICAL"  
Dim advertising : advertising = "CRITICAL" 
Dim fsmocheck : fsmocheck = "OK" 
Dim ridmanager : ridmanager = "CRITICAL" 
Dim machineaccount : machineaccount = "CRITICAL" 

cmd = "$env:ProgramData\CentraStage\Packages\DCDiag\dcdiagEN.exe /test:services /test:replications /test:advertising /test:fsmocheck /test:ridmanager /test:machineaccount"
call exec(cmd)
call printout()

function exec(strCmd)	
	dim objShell 
	Set objShell = WScript.CreateObject("WScript.Shell")		
	Dim objExecObject,lineout
	Set objExecObject = objShell.Exec(strCmd)
        On Error resume next	
	Do While Not objExecObject.StdOut.AtEndOfStream
		lineout=LCASE(objExecObject.StdOut.ReadLine())
'Each line output is sent to parse function to check for keywords and update status
		call parse(lineout)
	loop
	if (err.number <> 0 ) then
	        wscript.quit(intCritical)
	end if
End function

function parse(txtp)
'Parse output of dcdiag command and change state of checks
	if instr(txtp,"passed test") then	
'find position of last space
		intPosition = InStrRev(txtp, " ")
'get everything to the right of the space
		txtp = Right(txtp, Len(txtp) - intPosition)
		txtp = Replace(txtp,".","")
		txtp = Replace(txtp,chr(13),"")
		txtp = trim(txtp)		
		Select Case txtp
		case "services"
			services = "OK" 
		case "replications"
			replications = "OK"
		case "advertising"
			advertising = "OK" 
		case "fsmocheck"
			fsmocheck = "OK" 
		case "advertising"
			advertising = "OK"  
		case "ridmanager"
			ridmanager = "OK"
		case "machineaccount"
			machineaccount = "OK"
		end select
	elseif instr(txtp,"failed test") then
'find position of last space
		intPosition = InStrRev(txtp, " ")
'get everything to the right of the space
		txtp = Right(txtp, Len(txtp) - intPosition)
		txtp = Replace(txtp,".","")
		txtp = Replace(txtp,chr(13),"")
		txtp = trim(txtp)	
		Select Case txtp
		case "services"
			services = "CRITICAL" 
		case "replications"
			replications = "CRITICAL"
		case "advertising"
			advertising = "CRITICAL" 
		case "fsmocheck"
			fsmocheck = "CRITICAL" 
		case "advertising"
			advertising = "CRITICAL"  
		case "ridmanager"
			ridmanager = "CRITICAL"
		case "machineaccount"
			machineaccount = "CRITICAL"
		end select
	end if
end function

function printout()
'outputs result
	dim msg
	msg = "Services " & services & ": Replications " & replications & ": Advertising " & advertising & ": Fsmocheck " &_
	fsmocheck & ": Ridmanager " & ridmanager & ": Machineaccount " & machineaccount
	if instr(msg,"CRITICAL") then
        Wscript.Echo "<-Start Result->"
	Wscript.Echo "Result=" & msg
	Wscript.Echo "<-End Result->"		
		wscript.quit(intCritical)
	else
        Wscript.Echo "<-Start Result->"
	    Wscript.Echo "Result=OK"
	    Wscript.Echo "<-End Result->"
		wscript.quit(intOK)
	end if
end function
"@

if (!(test-path "$env:ProgramData\CentraStage\Packages\DCDiag\monitor-build$varVBBuild.vbs" -ErrorAction SilentlyContinue)) {
    remove-item "$env:ProgramData\CentraStage\Packages\DCDiag\*.vbs" -Force
    set-content -Value $varVB -Path "$env:ProgramData\CentraStage\Packages\DCDiag\monitor-build$varVBBuild.vbs"
}

cscript -nologo "$env:ProgramData\CentraStage\Packages\DCDiag\monitor-build$varVBBuild.vbs"
if (!$?) {
    exit 1
}


function write-DRMMDiag ($messages) {
    write-host  '<-Start Diagnostic->'
    foreach ($Message in $Messages) { $Message }
    write-host '<-End Diagnostic->'
} function write-DRRMAlert ($message) {
    write-host '<-Start Result->'
    write-host "Alert=$message"
    write-host '<-End Result->'
}
$version = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentVersion
if ($Version -lt "6.3") {
    write-DRRMAlert "Unsupported OS. Only Server 2012R2 and up are supported."
    exit 1
}

$MaxBackLog = $ENV:MaxBackLogFiles
$DFSFiles = Get-DfsrState
$connections = Get-DfsrConnection | Where-Object { $_.state -ne 'normal' }
$Folders = Get-DfsReplicatedFolder | Where-Object { $_.state -ne 'normal' }
$DFSHealth = invoke-command { if ($Connections) { "Fault connections found. Please investigate`n" }
    if ($Folders) { "Faulty folder found. Please investigate`n" }
    if ($DFSFiles.count -gt $Maxbacklog) { "There are more than $Maxbacklog in the backlog. Current Backlog: $($DFSFiles.count) `n" }
}

if (!$DFSHealth) {
    write-DRRMAlert "Healthy."
    write-DRMMDiag ($DFSHealth | Out-String)
}
else {
    write-DRRMAlert "Not Healthy."
    write-DRMMDiag ($DFSHealth | Out-String)
    exit 1
}