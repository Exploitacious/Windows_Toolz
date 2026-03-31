<#
.SYNOPSIS
    Performs various DNS lookups for a given domain and a list of common subdomains.

.DESCRIPTION
    This script queries for A, AAAA, MX, TXT, and NS records for the specified root domain.
    It then attempts to find A and AAAA records for a predefined list of common subdomains.
    All discovered records are collected and exported into a single CSV file.

.PARAMETER RootDomain
    The root domain name you want to query (e.g., "google.com"). This parameter is mandatory.

.EXAMPLE
    .\Get-DnsRecords.ps1 -RootDomain "example.com"

.EXAMPLE
    .\Get-DnsRecords.ps1 -RootDomain "example.com" -Verbose
    (This will show real-time progress of the DNS queries.)

.OUTPUTS
    A CSV file named 'DNS-Report-[RootDomain].csv' in the current directory containing the query results.
#>
[CmdletBinding()]
param (
  [Parameter(Mandatory = $true, HelpMessage = "Enter the root domain to query.")]
  [string]$RootDomain
)

#region Main Processing Block
# Initialize an array to store all the discovered DNS records.
$allRecords = @()

# Define the DNS record types to query for the root domain.
$rootRecordTypes = @('A', 'AAAA', 'MX', 'NS', 'TXT')

# --- Section 1: Query the Root Domain ---
Write-Verbose "Querying root domain '$RootDomain' for records: $($rootRecordTypes -join ', ')"

foreach ($type in $rootRecordTypes) {
  # Resolve the DNS name for the current record type.
  # -ErrorAction SilentlyContinue prevents the script from halting if a record type is not found.
  $results = Resolve-DnsName $RootDomain -Type $type -ErrorAction SilentlyContinue

  # Process the results based on the record type to extract the correct value.
  $processedResults = switch ($type) {
    'A' { $results | Select-Object @{N = 'QueryName'; E = { $_.Name } }, @{N = 'RecordType'; E = { $_.Type } }, @{N = 'RecordValue'; E = { $_.IPAddress } } }
    'AAAA' { $results | Select-Object @{N = 'QueryName'; E = { $_.Name } }, @{N = 'RecordType'; E = { $_.Type } }, @{N = 'RecordValue'; E = { $_.IPAddress } } }
    'MX' { $results | Select-Object @{N = 'QueryName'; E = { $_.Name } }, @{N = 'RecordType'; E = { $_.Type } }, @{N = 'RecordValue'; E = { "$($_.NameExchange) (Pref: $($_.Preference))" } } }
    'NS' { $results | Select-Object @{N = 'QueryName'; E = { $_.Name } }, @{N = 'RecordType'; E = { $_.Type } }, @{N = 'RecordValue'; E = { $_.NameHost } } }
    'TXT' { $results | Select-Object @{N = 'QueryName'; E = { $_.Name } }, @{N = 'RecordType'; E = { $_.Type } }, @{N = 'RecordValue'; E = { $_.Strings -join '; ' } } }
  }
    
  # Add the processed results to our main collection.
  if ($null -ne $processedResults) {
    $allRecords += $processedResults
  }
}

# --- Section 2: Enumerate Common Subdomains ---
# A curated list of common subdomains to check for.
$subdomains = @(
  "www", "mail", "blog", "dev", "ftp", "owa", "admin", "shop", "vpn",
  "portal", "test", "webmail", "remote", "autodiscover", "cpanel",
  "sip", "ns1", "ns2", "mta", "smtp", "internal", "corp", "api", "cdn", "portal", "login"
)

Write-Verbose "Starting subdomain enumeration for $($subdomains.Count) common names."

foreach ($sub in $subdomains) {
  # Construct the full domain name (e.g., "www.google.com").
  $currentDomain = "$sub.$RootDomain"
  Write-Verbose "Checking A/AAAA records for '$currentDomain'..."

  # Query for both A (IPv4) and AAAA (IPv6) records for the subdomain.
  # We combine the queries and process them together.
    ('A', 'AAAA') | ForEach-Object {
    $records = Resolve-DnsName -Name $currentDomain -Type $_ -ErrorAction SilentlyContinue |
    Select-Object @{N = 'QueryName'; E = { $_.Name } }, @{N = 'RecordType'; E = { $_.Type } }, @{N = 'RecordValue'; E = { $_.IPAddress } }
        
    # Add any found records to the main collection.
    if ($null -ne $records) {
      $allRecords += $records
    }
  }
}

# --- Section 3: Export Results to CSV ---
if ($allRecords.Count -gt 0) {
  # Define a dynamic output path based on the root domain.
  $outputPath = ".\DNS-Report-$RootDomain.csv"
    
  # Export the collected data to a CSV file.
  # -NoTypeInformation prevents the "#TYPE" header from being added to the file.
  $allRecords | Export-Csv -Path $outputPath -NoTypeInformation
    
  Write-Host "✅ DNS enumeration complete. Found $($allRecords.Count) records."
  Write-Host "Results exported to: $outputPath"
}
else {
  Write-Warning "No DNS records were found for the domain '$RootDomain'."
}

#endregion