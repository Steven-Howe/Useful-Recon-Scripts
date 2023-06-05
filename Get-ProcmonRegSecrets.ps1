<#
.SYNOPSIS
    Searches files for given search terms.
.DESCRIPTION
    Parses a Procmon .csv file for registry paths then obtains the keys and values for each path.
.NOTES
    Author: Steven Howe
    Date:   May 31,2023
.PARAMETER SourceFile
    Procmon CSV file location.
.PARAMETER OutputFile
    File to save resulting matches to.
.INPUTS
    None. You cannot pipe objects to Get-ProcmonRegSecrets.
.OUTPUTS
    If no output file is given, it will output an object containing Registry, Name, and Value properties.
.EXAMPLE
    Get-ProcmonRegSecrets -SourceFile 'C:\Users\Test\Documents\Logfile.CSV' -OutputFile 'C:\Users\Test\Documents\results.txt`
.EXAMPLE
    Get-ProcmonRegSecrets -SourceFile 'C:\Users\Test\Documents\Logfile.CSV
#>

function Get-ProcmonRegSecrets {
    [CmdletBinding()]

    Param (

        [Parameter(Mandatory)]
        [String]$SourceFile = "", # Procmon CSV file location

        [String]$OutputFile = "" # File to save resulting matches to
    )

if (-not (Test-Path $SourceFile))
{
    Write-Host "[-] $SourceFile does not exist!" -ForegroundColor Red
    return
}

Write-Host "[+] Obtaining registry paths from CSV file..." -ForegroundColor Yellow
$regPaths = Import-Csv $SourceFile | select -ExpandProperty Path | Sort-Object | Get-Unique

# Outputs to console if no OutpuFile arg given
if ($OutputFile -eq "") {
    Write-Host "[+] Searching for secrets..." -ForegroundColor Yellow

    # Outputs each registry key and value for each registry path
    foreach ($path in $regPaths) {
        $registry = Get-Item -Path Registry::$path
        foreach ($a in $registry) {
        ($a | Get-ItemProperty).Psobject.Properties |
        Where-Object { $_.Name -cnotlike 'PS*' } |
        Format-List -Property @{ Name = 'Registry'; Expression = { $a } },Name,Value
        }
    }
}else {
    Write-Host "[+] Created results file!" -ForegroundColor Green
    New-Item -ItemType "file" -Path $outputFile -ErrorAction SilentlyContinue
    Write-Host "[+] Created results file at: $OutputFile" -ForegroundColor Green

    # Outputs each registry key and value for each registry path
    foreach ($path in $regPaths) {
        $registry = Get-Item -Path Registry::$path
        foreach ($a in $registry) {
        ($a | Get-ItemProperty).Psobject.Properties |
        #Exclude powershell-properties in the object
        Where-Object { $_.Name -cnotlike 'PS*' } |
        Format-List -Property @{ Name = 'Registry'; Expression = { $a } },Name,Value |
        Out-File -FilePath $outputFile -Append
        }
    }
}
Write-Host "[+] Script Completed!" -ForegroundColor Green
}