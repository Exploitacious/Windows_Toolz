function Write-Alert {
    param([string]$Alert)
    Write-Host "<-Start Result->"
    Write-Host "CSMon_Result="$Alert
    Write-Host "<-End Result->"
    exit 1
}

#numbers of days to look for expiring certificates
$threshold = 30
#set deadline date
$deadline = (Get-Date).AddDays($threshold)

$flag = 0

$local = "Cert:\LocalMachine" | Get-ChildItem

$sort_cert = @()
$sort_cert_done = @()
$outprint = @()

Try {
    $local.Name | % {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($_, "LocalMachine")
        $store.Open("ReadOnly")
        $store.certificates | % {
            If ($_.NotAfter -lt $deadline) {
                $days_off = ($_.NotAfter - (Get-Date)).Days
                $sort_cert += $_ | Select Issuer, @{
                    Label = "ExpiresIn"; Expression = {
                        ($_.NotAfter - (Get-Date)).Days
                    }
                }
            }
        }
    }

    $sort_cert_done = $sort_cert | Sort-Object -Property ExpiresIn
    $sort_cert_done | % {
        $str = $_.Issuer.Substring(3, $_.Issuer.Length - 3)
        if ($str.IndexOf("=") -gt -1) {
            $str2 = $str.Substring(0, $str.IndexOf("=") - 4)
            $outprint += $str2 + ","
        }
        else {
            $outprint += $str + ","
        }
        if ($days_off -le $threshold) {
            $flag = 1
        }
    }
}
Catch {
    Write-Alert $($_.Exception.Message)
}

#ExitWithCode
if ($flag -eq 1) {  
    Write-Alert $outprint
}
else {
    exit 0
}

