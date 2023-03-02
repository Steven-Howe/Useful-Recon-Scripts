# Useful-Recon-Scripts
Recon automation scripts that could prove useful for penetration test engagements, bug bounty, or CTFs.

`nmap_recon.sh`: A Bash script that scans a network range for available hosts, conducts TCP and UDP nmap scans, also scans for vulnerabilities using the NSE <i>vuln</i> category, and displays exploits found, CVEs, and identified technologies. Organizes targets and findings into proper directories and files.

`interleave_wordlists.py`: A Python script that takes an N number of wordlists, interleaves the words of each wordlist into one master list while also de-duplicating words. The end result is a unique master wordlist which retains the order of the input wordlists.
