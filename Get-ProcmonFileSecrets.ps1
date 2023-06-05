<#
.SYNOPSIS
    Searches files for given search terms.
.DESCRIPTION
    Parses a Procmon .csv file for files then searches those files for given search terms.
.NOTES
    Author: Steven Howe
    Date:   May 31,2023
.PARAMETER SearchTerms
    Terms to search for e.g. ('password|key|username')
.PARAMETER SourceFile
    Procmon CSV file location.
.PARAMETER OutputFile
    File to save resulting matches to.
.INPUTS
    None. You cannot pipe objects to Get-ProcmonFileSecrets.
.OUTPUTS
    If no output file is given, it will output an object containing Path, LineNumber, and Line properties.
.EXAMPLE
    Get-ProcmonFileSecrets -SearchTerms 'password|key|username|database|token|secret' -SourceFile 'C:\Users\Test\Documents\Logfile.CSV' -OutputFile 'C:\Users\Test\Documents\results.txt`
.EXAMPLE
    Get-ProcmonFileSecrets -SearchTerms 'password|key|username|database|token|secret' -SourceFile 'C:\Users\Test\Documents\Logfile.CSV'
#>

function Get-ProcmonFileSecrets {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory)]
        [String]$SearchTerms = "", # Terms to search for e.g. ('password|key|username')

        [Parameter(Mandatory)]
        [String]$SourceFile = "", # Procmon CSV file location

        [String]$OutputFile = "" # File to save resulting matches to
    )

if (-not (Test-Path $SourceFile))
{
    Write-Host "[-] $SourceFile does not exist!" -ForegroundColor Red
    return
}

# Obtains all unique paths from CSV file
Write-Host "[+] Obtaining paths from CSV file..." -ForegroundColor Yellow
$paths = Import-Csv $SourceFile | select -ExpandProperty Path -ErrorAction Stop | Sort-Object | Get-Unique
Write-Host "[+] Retrieved paths from CSV file!" -ForegroundColor Green

# Outputs to console if no OutpuFile arg given
if ($OutputFile -eq "") {
    Write-Host "[+] Searching for secrets..." -ForegroundColor Yellow

    # Searches files only for terms and outputs to results file
    foreach ($path in $paths) {
        if ((Get-Item $path -ErrorAction SilentlyContinue) -is [System.IO.FileInfo]) {
            Select-String -Path $path -Pattern $SearchTerms -Encoding ascii -AllMatches -ErrorAction SilentlyContinue | 
            Format-List -Property Path,LineNumber,Line
            }
        }
}else {
    Write-Host "[+] Searching for secrets and adding to results file..." -ForegroundColor Yellow
    New-Item -ItemType "file" -Path $OutputFile -ErrorAction SilentlyContinue
    Write-Host "[+] Created results file at: $OutputFile" -ForegroundColor Green
    
    # Searches files only for terms and outputs to results file
    foreach ($path in $paths) {
        if ((Get-Item $path -ErrorAction SilentlyContinue) -is [System.IO.FileInfo]) {
            Select-String -Path $path -Pattern $SearchTerms -Encoding ascii -AllMatches -ErrorAction SilentlyContinue | 
            Format-List -Property Path,LineNumber,Line |
            Out-File -FilePath $OutputFile -Append
            }
        }
}
Write-Host "[+] Script Completed!" -ForegroundColor Green
}
