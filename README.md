# Useful-Recon-Scripts
Recon automation scripts that could prove useful for penetration test engagements, bug bounty, or CTFs.

`nmap_recon.sh`: A Bash script that scans a network range for available hosts, conducts TCP and UDP nmap scans, also scans for vulnerabilities using the NSE <i>vuln</i> category, and displays exploits found, CVEs, and identified technologies. Organizes targets and findings into proper directories and files.

`interleave_wordlists.py`: A Python script that takes an N number of wordlists, interleaves the words of each wordlist into one master list while also de-duplicating words. The end result is a unique master wordlist which retains the order of the input wordlists.

`Get-ProcmonRegSecrets.ps1`: Parses a Procmon .csv file for registry paths and obtains the keys and values under each path.

`Get-ProcmonFileSecrets.ps1`: Parses a Procmon .csv file for file paths then searches those files for given search terms.

`Get-ProcmonDllHijack.ps1`: Parses a Procmon .csv file for DLL paths, identifies writeable paths, and attempts exploitation by using a provided malicious DLL and restarting the target process. Script cleans up after itself by restoring original DLL file name and deleting the malicious DLL file.
