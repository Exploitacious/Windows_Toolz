# Created by Alex Ivantsov
# Updated 9/19/2021
# Ver. 3.0
 
[cmdletbinding()]

param([Parameter(ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$True)]$Computer = '.') 

$shares = Get-WmiObject -Class win32_share -ComputerName $computer | Select-Object -ExpandProperty Name 
 
foreach ($share in $shares) { 
    $acl = $null 
    Write-Host $share -ForegroundColor Green 
    Write-Host $('-' * $share.Length) -ForegroundColor Green 
    $objShareSec = Get-WMIObject -Class Win32_LogicalShareSecuritySetting -Filter "name='$Share'"  -ComputerName $computer
    try { 
        $SD = $objShareSec.GetSecurityDescriptor().Descriptor   
        foreach($ace in $SD.DACL){  
            $UserName = $ace.Trustee.Name     
            If ($Null -ne $ace.Trustee.Domain) {$UserName = "$($ace.Trustee.Domain)\$UserName"}   
            If ($Null -eq $ace.Trustee.Name) {$UserName = $ace.Trustee.SIDString }     
            [Array]$ACL += New-Object Security.AccessControl.FileSystemAccessRule($UserName, $ace.AccessMask, $ace.AceType) 
            } #end foreach ACE           
        } # end try 
    catch 
        { Write-Host "Unable to obtain permissions for $share" } 
    $ACL 
    Write-Host $('=' * 50) 
    } # end foreach $share