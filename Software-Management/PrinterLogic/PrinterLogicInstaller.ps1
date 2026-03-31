[CmdletBinding()]
param (
    # PrinterLogic PLHomeURL
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $env:PLHomeURL,

    # Authorization Code
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]
    $env:PLAuthorizationCode,

    # MSI Location
    [Parameter()]
    [System.IO.FileInfo]
    $MsiLocation,

    # Location for temporary files
    [Parameter()]
    [System.IO.DirectoryInfo]
    $TempLocation,

    # Whether or not to perform an automatic checkin after installation
    [Parameter()]
    [switch]
    $Checkin = $false
)


# ----- FUNCTION DEFINITIONS
function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Test-PrinterLogicIsInstalled {
    $productCode = "{A9DE0858-9DDD-4E1B-B041-C2AA90DCBF74}"
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\$productCode") {
        return $true
    }
    if (Test-Path "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\$productCode") {
        return $true
    }

    return $false
}

function Install-PrinterLogicClient {
    $params = @(
        "/i"
        "$msi"
        "/qn"
        "PLHomeURL=$env:PLHomeURL"
        "AUTHORIZATION_CODE=$env:PLAuthorizationCode"
    )
    if ($null -ne $TempLocation) {
        $params += "TEMPPATH=$TempLocation"
    }
    $p = Start-Process `
        -FilePath "$env:SystemRoot\system32\msiexec.exe" `
        -ArgumentList $params `
        -PassThru
    $p.WaitForExit()

    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
        throw "Unable to install PrinterLogic Client: Error code $($p.ExitCode)"
    }
}

function Update-PrinterLogicClient {
    # To be safe, first clear out the classes registry key
    Remove-Item `
        -Path "HKLM:\SOFTWARE\PrinterLogic\PrinterInstaller\Classes" `
        -Force

    $params = @(
        "/i"
        "$msi"
        "/qn"
        "ADDLOCAL=ALL"
        "REINSTALLMODE=vomusa"
        "REINSTALL=ALL"
        "PLHomeURL=$env:PLHomeURL"
        "AUTHORIZATION_CODE=$env:PLAuthorizationCode"
    )
    if ($null -ne $TempLocation) {
        $params += "TEMPPATH=$TempLocation"
    }
    $p = Start-Process `
        -FilePath "$env:SystemRoot\system32\msiexec.exe" `
        -ArgumentList $params `
        -PassThru
    $p.WaitForExit()

    if ($p.ExitCode -ne 0 -and $p.ExitCode -ne 3010) {
        throw "Unable to update PrinterLogic Client: Error code $($p.ExitCode)"
    }

    # Sleep for 5 seconds
    Start-Sleep -Seconds 5

    # Start the PrinterInstallerLauncher service
    Start-Service -Name PrinterInstallerLauncher
}
# ----- END FUNCTION DEFINITIONS


# ----- MAIN SCRIPT STARTS HERE

Write-Output "Command called with the following parameters:"
Write-Output "  PLHomeURL=$env:PLHomeURL"
Write-Output "  MsiLocation=$MsiLocation"
Write-Output "  TempLocation=$TempLocation"
Write-Output "  Checkin=$Checkin"

# Make sure we are elevated
if (!(Test-IsAdmin)) {
    $params = @(
        "-NoLogo"
        "-NoProfile"
        "-ExecutionPolicy RemoteSigned"
        "-File `"$PSCommandPath`""
        "-PLHomeURL $env:PLHomeURL"
        "-PLAuthorizationCode $env:PLAuthorizationCode"
    )
    if ($null -ne $MsiLocation) {
        $params += "-MsiLocation $MsiLocation"
    }
    if ($null -ne $TempLocation) {
        $params += "-TempLocation $TempLocation"
    }
    if ($Checkin) {
        $params += "-Checkin"
    }

    Start-Process "$($(Get-Process -id $pid | Get-Item).FullName)" -Verb RunAs -ArgumentList $params
    exit
}

# If the MsiLocation was specified, use that instead of downloading the latest
if ($MsiLocation) {
    if (!(Test-Path $MsiLocation -PathType Leaf)) {
        throw "The MSI file does not exist"
    }
    $msi = $MsiLocation
}
else {
    $downloadFolder = [System.IO.Path]::GetTempPath()
    $msi = [System.IO.Path]::Combine($downloadFolder, "PrinterInstallerClient.msi")

    # Add support for TLS1.1 or TLS1.2
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls11 -bor `
        [System.Net.SecurityProtocolType]::Tls12

    # Download the latest PrinterLogic Client
    Write-Output "Downloading latest PrinterLogic client..."
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri https://downloads.printercloud.com/client/setup/PrinterInstallerClient.msi `
        -UseBasicParsing `
        -OutFile "$msi"
    $ProgressPreference = 'Continue'
}

# Install PrinterLogic
if (!(Test-PrinterLogicIsInstalled)) {
    Write-Output "Installing PrinterLogic Client..."
    Install-PrinterLogicClient
}
else {
    Write-Output "Updating PrinterLogic Client..."
    Update-PrinterLogicClient
}

# Optionally perform a checkin
if ($Checkin) {
    $params = @("refresh")
    $p = Start-Process `
        -FilePath "C:\Program Files (x86)\Printer Properties Pro\Printer Installer Client\PrinterInstallerClient.exe" `
        -ArgumentList $params `
        -PassThru
    $p.WaitForExit()
}

# SIG # Begin signature block
# MIIomwYJKoZIhvcNAQcCoIIojDCCKIgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB+SW42oUtCmmQp
# vfHuL9faVj/xjkOspM3LI3g/LKVKwqCCEYkwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggX0MIIEXKADAgECAhAgcVA1
# 8+cWSTirmSX1fvAcMA0GCSqGSIb3DQEBDAUAMFQxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBDQSBSMzYwHhcNMjExMDA1MDAwMDAwWhcNMjQwOTA5MjM1OTU5
# WjBKMQswCQYDVQQGEwJVUzENMAsGA1UECAwEVXRhaDEVMBMGA1UECgwMUHJpbnRl
# ckxvZ2ljMRUwEwYDVQQDDAxQcmludGVyTG9naWMwggGiMA0GCSqGSIb3DQEBAQUA
# A4IBjwAwggGKAoIBgQD8HtwZks6sqDKyUWA6ipy1PJIxkkDF9MaXVfBYKpv79z6F
# mhSMqL+83OzM9SrlI6uMiKKpvIMt4oZofccSDBC8v9g0Otxt7QT5vypZo68djctC
# 54b+H2zDIyGBtYRB2ubdMU6v93H5AY+wRC773txb5RFxJE+H7SCSr3013BoYooTk
# u0P/ZWXRHdNecHI89XTMj1atRU+R3OGWe20pYauE0JE/szYaNLfFA3PFmckwsnnV
# rpvOAf2sX/1URSThIfb/NglgaDpmaZQCX5ykuVJhBdRvcw1w+r/7enWxs7m3kVqb
# AwwpSTlTT45L/nXc2wgNOxN0NyYcr26djWPyRSXBF/WB+6tppGn7kviqTjlQZrIr
# 1PGrHuWBc4hf0/MGLEyjIyl46b4u57pfric3ukn34sp04tPhigcWhrv/KsjaiEr7
# Azf986NZ6olZOaBHItzZLn3/13sy/lEayyWY94eASVDN/rI2Wi2/D2nhG/OAnx0p
# TgTTeCDEc03IVyxhgpUCAwEAAaOCAcowggHGMB8GA1UdIwQYMBaAFA8qyyCHKLjs
# b0iuK1SmKaoXpM0MMB0GA1UdDgQWBBRGh1kg+Fq41o1KpJLHbGUGHo19CjAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDAzAR
# BglghkgBhvhCAQEEBAMCBBAwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwIwJTAj
# BggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQBMEkG
# A1UdHwRCMEAwPqA8oDqGOGh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nQ0FSMzYuY3JsMHkGCCsGAQUFBwEBBG0wazBEBggrBgEF
# BQcwAoY4aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNp
# Z25pbmdDQVIzNi5jcnQwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28u
# Y29tMCwGA1UdEQQlMCOBIWNvcmV5LmVyY2FuYnJhY2tAcHJpbnRlcmxvZ2ljLmNv
# bTANBgkqhkiG9w0BAQwFAAOCAYEARic/mcJBRReYOSb5O8oZDMRjRODI3nGZSy6u
# 2/WPaJwLBK6f2k3SGvjsG358mqxe2jWV0zKICcm/UfScqQp72h9NKhzu4jDS4SvG
# gNogfspwFVCcJELxRDjAYPFxdcUyhWaXjY90fTGFcTVkdc9tWj6PdrHg3GoRAkri
# NDnVOkCBXj8VVjxqzm+toVXZCuMHPyq34DtA+8dUam3rcFUPtoOYt/OhNv9RLanD
# tp7l1VyPi8/BWugFmPqZxOSFFkZX0QENhw7XVPBAbGhms8Nl0CryAEVm5jduAhE3
# uDEaVt7ikSoMnVf73Nag6VsCbcbpKlZwpUfdRojKeU32kwK7ALpLwjFgz9f87/Lm
# GTmnMWlZWZV5RotsGMKtTGeqCXRzXo8pbnbNg8QIvleZljs4QW3QoiJYGKboUNQE
# 3kVkSHFZ2bq2atFeUq2jdCYOZNVvZI1ewaLspb7vFieJi9JPb9qQTelVpyVkm4xQ
# 4rZGU7AunYH757EVm61Tc58o77UDMIIGGjCCBAKgAwIBAgIQYh1tDFIBnjuQeRUg
# iSEcCjANBgkqhkiG9w0BAQwFADBWMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25p
# bmcgUm9vdCBSNDYwHhcNMjEwMzIyMDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBUMQsw
# CQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJT
# ZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MIIBojANBgkqhkiG9w0B
# AQEFAAOCAY8AMIIBigKCAYEAmyudU/o1P45gBkNqwM/1f/bIU1MYyM7TbH78WAeV
# F3llMwsRHgBGRmxDeEDIArCS2VCoVk4Y/8j6stIkmYV5Gej4NgNjVQ4BYoDjGMwd
# jioXan1hlaGFt4Wk9vT0k2oWJMJjL9G//N523hAm4jF4UjrW2pvv9+hdPX8tbbAf
# I3v0VdJiJPFy/7XwiunD7mBxNtecM6ytIdUlh08T2z7mJEXZD9OWcJkZk5wDuf2q
# 52PN43jc4T9OkoXZ0arWZVeffvMr/iiIROSCzKoDmWABDRzV/UiQ5vqsaeFaqQdz
# Ff4ed8peNWh1OaZXnYvZQgWx/SXiJDRSAolRzZEZquE6cbcH747FHncs/Kzcn0Cc
# v2jrOW+LPmnOyB+tAfiWu01TPhCr9VrkxsHC5qFNxaThTG5j4/Kc+ODD2dX/fmBE
# CELcvzUHf9shoFvrn35XGf2RPaNTO2uSZ6n9otv7jElspkfK9qEATHZcodp+R4q2
# OIypxR//YEb3fkDn3UayWW9bAgMBAAGjggFkMIIBYDAfBgNVHSMEGDAWgBQy65Ka
# /zWWSC8oQEJwIDaRXBeF5jAdBgNVHQ4EFgQUDyrLIIcouOxvSK4rVKYpqhekzQww
# DgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYI
# KwYBBQUHAwMwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEEATBLBgNVHR8ERDBC
# MECgPqA8hjpodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2Rl
# U2lnbmluZ1Jvb3RSNDYuY3JsMHsGCCsGAQUFBwEBBG8wbTBGBggrBgEFBQcwAoY6
# aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdS
# b290UjQ2LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20w
# DQYJKoZIhvcNAQEMBQADggIBAAb/guF3YzZue6EVIJsT/wT+mHVEYcNWlXHRkT+F
# oetAQLHI1uBy/YXKZDk8+Y1LoNqHrp22AKMGxQtgCivnDHFyAQ9GXTmlk7MjcgQb
# DCx6mn7yIawsppWkvfPkKaAQsiqaT9DnMWBHVNIabGqgQSGTrQWo43MOfsPynhbz
# 2Hyxf5XWKZpRvr3dMapandPfYgoZ8iDL2OR3sYztgJrbG6VZ9DoTXFm1g0Rf97Aa
# en1l4c+w3DC+IkwFkvjFV3jS49ZSc4lShKK6BrPTJYs4NG1DGzmpToTnwoqZ8fAm
# i2XlZnuchC4NPSZaPATHvNIzt+z1PHo35D/f7j2pO1S8BCysQDHCbM5Mnomnq5aY
# cKCsdbh0czchOm8bkinLrYrKpii+Tk7pwL7TjRKLXkomm5D1Umds++pip8wH2cQp
# f93at3VDcOK4N7EwoIJB0kak6pSzEu4I64U6gZs7tS/dGNSljf2OSSnRr7KWzq03
# zl8l75jy+hOds9TWSenLbjBQUGR96cFr6lEUfAIEHVC1L68Y1GGxx4/eRI82ut83
# axHMViw1+sVpbPxg51Tbnio1lB93079WPFnYaOvfGAA0e0zcfF/M9gXr+korwQTh
# 2Prqooq2bYNMvUoUKD85gnJ+t0smrWrb8dee2CvYZXD5laGtaAxOfy/VKNmwuWuA
# h9kcMYIWaDCCFmQCAQEwaDBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGln
# byBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcg
# Q0EgUjM2AhAgcVA18+cWSTirmSX1fvAcMA0GCWCGSAFlAwQCAQUAoIHQMBkGCSqG
# SIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3
# AgEVMC8GCSqGSIb3DQEJBDEiBCAQMCmh1rJE3iIdshonjPhErIoJ3nEQacMgjek9
# vnetNzBkBgorBgEEAYI3AgEMMVYwVKAygDAAUAByAGkAbgB0AGUAcgAgAEkAbgBz
# AHQAYQBsAGwAZQByACAAQwBsAGkAZQBuAHShHoAcaHR0cDovL3d3dy5wcmludGVy
# bG9naWMuY29tIDANBgkqhkiG9w0BAQEFAASCAYDZ5bnJoDl1/MFsz+CSgq5jbeEb
# qonH3xMSUhCHTQeA4Kq0sfPQP0GC9lv1NWQszd0548cwtxlAO/S1L0cTZ8zhTBt6
# 0UCbo0DbcTYP3LizWzbOXccx1/c1bVURF3vIdaRyySCEcrLWeKcFg0BXOulxnQc+
# Egh11NJR4XSfUKumBjtsVuuJxKqxzvzLgzvY99Iroy5T5mAVc9e4QPVOLjqsLFDx
# EQl2RykasqMD2DxJ/BxfcmOp67oPJ7GUG1enA2Hs2a6Fm5saD8Yu1Aml//qJWatz
# HbUZcpOG357b7JpqiOTp6WNI08TfNJdguYfpGjyS6YO3dXBicMAB4FtNkUSlLAio
# otK8h8EpsHLx0/6A5wkKkTJsEe1qFxieFHsFrAmluEdAxmwlvgOJtDhJE1INiqYn
# +He2I+id90uOUy/48UIiScT3oqOq+H10aCbHBE02XHa9bh+IEJVhPv4D9OW3M/bb
# TOvy+/L/vMIF0wHKR8HCB84jOZpzNnXvucVt2oyhghN+MIITegYKKwYBBAGCNwMD
# ATGCE2owghNmBgkqhkiG9w0BBwKgghNXMIITUwIBAzEPMA0GCWCGSAFlAwQCAgUA
# MIIBCwYLKoZIhvcNAQkQAQSggfsEgfgwgfUCAQEGCisGAQQBsjECAQEwMTANBglg
# hkgBZQMEAgEFAAQgPXXu0lBZNoEmNPNtVH3u8eC+6U+f5v0CmqVrTr+Yq0gCE3BZ
# qfvwQpmVfC5t+DJRt5IpWeAYDzIwMjIwMjE0MTU1NDQ4WqCBiqSBhzCBhDELMAkG
# A1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMH
# U2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDDCNTZWN0
# aWdvIFJTQSBUaW1lIFN0YW1waW5nIFNpZ25lciAjMqCCDfswggcHMIIE76ADAgEC
# AhEAjHegAI/00bDGPZ86SIONazANBgkqhkiG9w0BAQwFADB9MQswCQYDVQQGEwJH
# QjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3Jk
# MRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNlY3RpZ28gUlNB
# IFRpbWUgU3RhbXBpbmcgQ0EwHhcNMjAxMDIzMDAwMDAwWhcNMzIwMTIyMjM1OTU5
# WjCBhDELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQ
# MA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYD
# VQQDDCNTZWN0aWdvIFJTQSBUaW1lIFN0YW1waW5nIFNpZ25lciAjMjCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAJGHSyyLwfEeoJ7TB8YBylKwvnl5XQlm
# Bi0vNX27wPsn2kJqWRslTOrvQNaafjLIaoF9tFw+VhCBNToiNoz7+CAph6x00Bti
# vD9khwJf78WA7wYc3F5Ok4e4mt5MB06FzHDFDXvsw9njl+nLGdtWRWzuSyBsyT5s
# /fCb8Sj4kZmq/FrBmoIgOrfv59a4JUnCORuHgTnLw7c6zZ9QBB8amaSAAk0dBahV
# 021SgIPmbkilX8GJWGCK7/GszYdjGI50y4SHQWljgbz2H6p818FBzq2rdosggNQt
# lQeNx/ULFx6a5daZaVHHTqadKW/neZMNMmNTrszGKYogwWDG8gIsxPnIIt/5J4Kh
# g1HCvMmCGiGEspe81K9EHJaCIpUqhVSu8f0+SXR0/I6uP6Vy9MNaAapQpYt2lRtm
# 6+/a35Qu2RrrTCd9TAX3+CNdxFfIJgV6/IEjX1QJOCpi1arK3+3PU6sf9kSc1ZlZ
# xVZkW/eOUg9m/Jg/RAYTZG7p4RVgUKWx7M+46MkLvsWE990Kndq8KWw9Vu2/eGe2
# W8heFBy5r4Qtd6L3OZU3b05/HMY8BNYxxX7vPehRfnGtJHQbLNz5fKrvwnZJaGLV
# i/UD3759jg82dUZbk3bEg+6CviyuNxLxvFbD5K1Dw7dmll6UMvqg9quJUPrOoPMI
# gRrRRKfM97gxAgMBAAGjggF4MIIBdDAfBgNVHSMEGDAWgBQaofhhGSAPw0F3RSiO
# 0TVfBhIEVTAdBgNVHQ4EFgQUaXU3e7udNUJOv1fTmtufAdGu3tAwDgYDVR0PAQH/
# BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwQAYD
# VR0gBDkwNzA1BgwrBgEEAbIxAQIBAwgwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9z
# ZWN0aWdvLmNvbS9DUFMwRAYDVR0fBD0wOzA5oDegNYYzaHR0cDovL2NybC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUlNBVGltZVN0YW1waW5nQ0EuY3JsMHQGCCsGAQUFBwEB
# BGgwZjA/BggrBgEFBQcwAoYzaHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UlNBVGltZVN0YW1waW5nQ0EuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5z
# ZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEASgN4kEIz7Hsagwk2M5hVu51A
# BjBrRWrxlA4ZUP9bJV474TnEW7rplZA3N73f+2Ts5YK3lcxXVXBLTvSoh90ihaZX
# u7ghJ9SgKjGUigchnoq9pxr1AhXLRFCZjOw+ugN3poICkMIuk6m+ITR1Y7ngLQ/P
# ATfLjaL6uFqarqF6nhOTGVWPCZAu3+qIFxbradbhJb1FCJeA11QgKE/Ke7OzpdIA
# sGA0ZcTjxcOl5LqFqnpp23WkPnlomjaLQ6421GFyPA6FYg2gXnDbZC8Bx8GhxySU
# o7I8brJeotD6qNG4JRwW5sDVf2gaxGUpNSotiLzqrnTWgufAiLjhT3jwXMrAQFzC
# n9UyHCzaPKw29wZSmqNAMBewKRaZyaq3iEn36AslM7U/ba+fXwpW3xKxw+7OkXfo
# IBPpXCTH6kQLSuYThBxN6w21uIagMKeLoZ+0LMzAFiPJkeVCA0uAzuRN5ioBPsBe
# haAkoRdA1dvb55gQpPHqGRuAVPpHieiYgal1wA7f0GiUeaGgno62t0Jmy9nZay9N
# 2N4+Mh4g5OycTUKNncczmYI3RNQmKSZAjngvue76L/Hxj/5QuHjdFJbeHA5wsCqF
# arFsaOkq5BArbiH903ydN+QqBtbD8ddo408HeYEIE/6yZF7psTzm0Hgjsgks4iZi
# vzupl1HMx0QygbKvz98wggbsMIIE1KADAgECAhAwD2+s3WaYdHypRjaneC25MA0G
# CSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEplcnNl
# eTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1Qg
# TmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9uIEF1
# dGhvcml0eTAeFw0xOTA1MDIwMDAwMDBaFw0zODAxMTgyMzU5NTlaMH0xCzAJBgNV
# BAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcTB1Nh
# bGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDElMCMGA1UEAxMcU2VjdGln
# byBSU0EgVGltZSBTdGFtcGluZyBDQTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCC
# AgoCggIBAMgbAa/ZLH6ImX0BmD8gkL2cgCFUk7nPoD5T77NawHbWGgSlzkeDtevE
# zEk0y/NFZbn5p2QWJgn71TJSeS7JY8ITm7aGPwEFkmZvIavVcRB5h/RGKs3EWsnb
# 111JTXJWD9zJ41OYOioe/M5YSdO/8zm7uaQjQqzQFcN/nqJc1zjxFrJw06PE37PF
# cqwuCnf8DZRSt/wflXMkPQEovA8NT7ORAY5unSd1VdEXOzQhe5cBlK9/gM/REQpX
# hMl/VuC9RpyCvpSdv7QgsGB+uE31DT/b0OqFjIpWcdEtlEzIjDzTFKKcvSb/01Mg
# x2Bpm1gKVPQF5/0xrPnIhRfHuCkZpCkvRuPd25Ffnz82Pg4wZytGtzWvlr7aTGDM
# qLufDRTUGMQwmHSCIc9iVrUhcxIe/arKCFiHd6QV6xlV/9A5VC0m7kUaOm/N14Tw
# 1/AoxU9kgwLU++Le8bwCKPRt2ieKBtKWh97oaw7wW33pdmmTIBxKlyx3GSuTlZic
# l57rjsF4VsZEJd8GEpoGLZ8DXv2DolNnyrH6jaFkyYiSWcuoRsDJ8qb/fVfbEnb6
# ikEk1Bv8cqUUotStQxykSYtBORQDHin6G6UirqXDTYLQjdprt9v3GEBXc/Bxo/tK
# fUU2wfeNgvq5yQ1TgH36tjlYMu9vGFCJ10+dM70atZ2h3pVBeqeDAgMBAAGjggFa
# MIIBVjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4EFgQU
# GqH4YRkgD8NBd0UojtE1XwYSBFUwDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAA
# MFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VS
# VHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDB2BggrBgEFBQcBAQRq
# MGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRydXN0LmNvbS9VU0VSVHJ1
# c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNl
# cnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAbVSBpTNdFuG1U4GRdd8DejIL
# LSWEEbKw2yp9KgX1vDsn9FqguUlZkClsYcu1UNviffmfAO9Aw63T4uRW+VhBz/FC
# 5RB9/7B0H4/GXAn5M17qoBwmWFzztBEP1dXD4rzVWHi/SHbhRGdtj7BDEA+N5Pk4
# Yr8TAcWFo0zFzLJTMJWk1vSWVgi4zVx/AZa+clJqO0I3fBZ4OZOTlJux3LJtQW1n
# zclvkD1/RXLBGyPWwlWEZuSzxWYG9vPWS16toytCiiGS/qhvWiVwYoFzY16gu9jc
# 10rTPa+DBjgSHSSHLeT8AtY+dwS8BDa153fLnC6NIxi5o8JHHfBd1qFzVwVomqfJ
# N2Udvuq82EKDQwWli6YJ/9GhlKZOqj0J9QVst9JkWtgqIsJLnfE5XkzeSD2bNJaa
# CV+O/fexUpHOP4n2HKG1qXUfcb9bQ11lPVCBbqvw0NP8srMftpmWJvQ8eYtcZMzN
# 7iea5aDADHKHwW5NWtMe6vBE5jJvHOsXTpTDeGUgOw9Bqh/poUGd/rG4oGUqNODe
# qPk85sEwu8CgYyz8XBYAqNDEf+oRnR4GxqZtMl20OAkrSQeq/eww2vGnL8+3/frQ
# o4TZJ577AWZ3uVYQ4SBuxq6x+ba6yDVdM3aO8XwgDCp3rrWiAoa6Ke60WgCxjKvj
# +QrJVF3UuWp0nr1IrpgxggQtMIIEKQIBATCBkjB9MQswCQYDVQQGEwJHQjEbMBkG
# A1UECBMSR3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxJTAjBgNVBAMTHFNlY3RpZ28gUlNBIFRpbWUg
# U3RhbXBpbmcgQ0ECEQCMd6AAj/TRsMY9nzpIg41rMA0GCWCGSAFlAwQCAgUAoIIB
# azAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTIy
# MDIxNDE1NTQ0OFowPwYJKoZIhvcNAQkEMTIEMJDQHez+4uqLh9gkr8ZrgsozYVyN
# z17Zam/OPnWwUcaJkGSKDH+rsjq6fsqpGuPsRDCB7QYLKoZIhvcNAQkQAgwxgd0w
# gdowgdcwFgQUlRE3EB2ILzG9UT+UmtpMaK2MCPUwgbwEFALWW5Xig3DBVwCV+oj5
# I92Tf62PMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEpl
# cnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJV
# U1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9u
# IEF1dGhvcml0eQIQMA9vrN1mmHR8qUY2p3gtuTANBgkqhkiG9w0BAQEFAASCAgBX
# nLi4V7QtSdcG9HLXY0lTGx+bWcqmuQXR8gPBEKwg3T+eKz2ncQrw38BT2Tfu0ZWw
# TePNPCzQaftgRtJQ5olsh3uo31zxt2kt4WS53duHkKYwGa6TpmLk3D7VmIgEmHVp
# Q2PR/tGewuFXZGcMGQYyts9Z74BhtOcz5wqjL3vu7rkN+2sAa4TAcs/zfpJve8+P
# F9zVIKbAiLTSkTYIePOh/+SH2mG4cVXoer4KM+ly4h7hztlLwWrILK7J5kPEpnxr
# VbbZxxhB3db4ISdDvSQpEDvJqz2igR/URjX5hOlZlHvvtQsKhqupYuqIUv8zk+zs
# kRhreRoFUawC5v+zdaftOd0KSAPhuekW1AOfaqVTFtprqRrLWbIE1hyBmX4Q1KIx
# aHu1FFs6MFg7OJVjC2PS5G5v/a83wd064B1gtMvyuo7PfLqD9HBeA+Bd/JdAwmsR
# ijLNFhP1MXKqhyGl+OO7tKnFbRU30PrsR4MgMt8Xw9K0jHJSv20K2Ebbzo6LyRCr
# TB6l0nfWOY/czwx9a1QtNMKEwKnzpKYyOEDobrymRiuevbEzSaiRHhwkO0eDKgeb
# SjVllhwCmliKVeKtoY/xBuCGuQxVSqltkHZTS96ptv+3JSFbUf18iJ1a/cqqiz25
# dz4BBAL1YCjALgz9re+uwiDQD+y+POE3zTV6HMVmpQ==
# SIG # End signature block
