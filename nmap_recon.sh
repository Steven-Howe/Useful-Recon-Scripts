#!/bin/bash

# Print help information if no args given, requires sudo privileges for nmap update,UDP, and aggressive scans
if [ $# -ne 2 ]; then
   echo "Usage: sudo ./nmap_recon.sh <IP Range> <nmap speed (e.g. T1-T4)>";
   exit 1;
fi

# Determines if script is sourced, alters exit functionality accordingly
source_detection () {
    [[ "$0" != "$BASH_SOURCE" ]] && sourced=1 || sourced=0
    if [[ $sourced -eq 1 ]]; then
        ret='return'
    else
        ret='exit'
    fi
}
source_detection

# Grab arguments and assign to variables
ip_range=$1
nmap_speed=$2

echo -e "[+] Script starting...\n"

# Create needed folders and files, tee requires existing folders and files to work
echo -e "[+] Creating necessary files and folders...\n"
mkdir -p scans exploits
touch scans/open_tcp.ports scans/open_udp.ports scans/web.ports exploits/technologies.txt exploits/vulners.exploits exploits/vulners.cves

# Update databases
echo -e "[+] Updating databases...\n"
nmap --script-updatedb
searchsploit --update

# Scan for avaialble hosts on the subnet
echo -e "[+] Starting nmap scan for available hosts...\n"
nmap -sn "$ip_range" -oG scans/open.hosts || { echo "[-] Unable to scan for available hosts!"; $ret 1; }

# Create target file for nmap
echo -e "[+] Created list of targets...\n"
grep -v \# scans/open.hosts | cut -d " " -f2 > targets.txt || { echo "[-] Unable to create list of targets!"; $ret 1; }

# Create folders for each found IP
echo -e "[+] Created directories for each target...\n"
for ip in $(cat targets.txt ); do mkdir -p "$ip" || { echo "[-] Unable to create directory for $ip!"; $ret 1; }; done 

# For each IP, do standard script and all TCP ports, save to each IP's folder
echo -e "[+] Starting nmap scan of all TCP ports...\n"
for ip in $(cat targets.txt ); do nmap -sC -sT -"$nmap_speed" -p- "$ip" -oA "$ip"/tcp.all || { echo "[-] Unable to complete TCP scan for $ip!"; $ret 1; }; done

# Recursively find all found open TCP ports, format it for use with nmap, save to file
open_tcp_ports=$(grep -R open */*.gnmap | grep -Po "([\d]+/open)" | cut -d "/" -f1 | sort -un | xargs | tr " " "," | tee scans/open_tcp.ports) || { echo "[-] Unable to create list of all open TCP ports!"; $ret 1; }
echo -e "All open TCP ports:\n""$open_tcp_ports"

# For each IP, do standard script and fast UDP ports, save to each IP's folder
echo -e "\n[+] Starting nmap scan of fast UDP ports...\n"
for ip in $(cat targets.txt ); do sudo nmap -sC -sU -"$nmap_speed" -F "$ip" -oA "$ip"/udp.all || { echo "[-] Unable to complete UDP scan for $ip!"; $ret 1; }; done 

# Recursively find all found open UDP ports, format it for use with nmap, save to file
open_udp_ports=$(grep -R open */udp.*.gnmap | grep -Po "[\d]+/open/udp" | cut -d "/" -f1 | sort -un | xargs | tr " " "," | tee scans/open_udp.ports) || { echo "[-] Unable to create list of all open UDP ports!"; $ret 1; }
echo -e "[+] All open UDP ports:\n""$open_udp_ports"

# Conduct agressive and vulnerability scan for each IP on UDP and TCP open ports
echo -e "\n[+] Starting nmap aggressive scan of all open TCP and UDP ports...\n"
# Will alter scan if no UDP ports
if [ -z "$open_udp_ports" ]
then
	for ip in $(cat targets.txt); do sudo nmap -Pn -sT -sU -A -"$nmap_speed" -p "$open_tcp_ports" --open $ip --script vuln -oA $ip/agg.scan || { echo "[-] Unable to do agressive scan of $ip!"; $ret 1; }; done
else
	for ip in $(cat targets.txt); do sudo nmap -Pn -sT -sU -A -"$nmap_speed" -p U:"$open_udp_ports",T:"$open_tcp_ports" --open $ip --script vuln -oA "$ip"/agg.scan || { echo "[-] Unable to do agressive scan of $ip!"; $ret 1; }; done
fi

# Display identified exploits for all targets sorted by highest CVSS and save to file
echo -e "[+] Finding all identified exploits against targets...\n"
grep -R ".*EXPLOIT.*" */agg.scan.nmap | awk '{ print $1, $3, $4 }' | sed 's/\/agg.scan.nmap:|/:/g' | sort -ru -k2 | tee exploits/vulners.exploits || { echo '[-] Unable to create file of identified exploits!'; $ret 1; }

# Display all identified CVE's for all targets sorted by highest CVSS and save to file
echo -e "[+] Finding all identified CVEs against targets...\n"
grep -R "CVE" */agg.scan.nmap | sort -u | grep -v mitre | sed 's/IDs:  CVE:/      /g; s/\/agg.scan.nmap:|/:/g' | sort -rn -k3 | tr -d "_" | tee exploits/vulners.cves || { echo '[-] Unable to create file of identified CVEs!'; $ret 1; }

# Display identified software from nmap scans and save to a file
echo -e "[+] Finding all identified software and versions for targets...\n"
grep -RPo "cpe:/a:[\w:\.]+" */agg.scan.xml | sed 's/\/agg.scan.xml:/ /g; s/:/ /g; s/_/ /g' | awk '{ $2="";$3=""; print $0 }' | sort -u -k2 | sort -t. -nk4 | tee exploits/technologies.txt || { echo '[-] Unable to create file of identified technologies!'; $ret 1; }

# Identify open web ports on targets
echo -e "[+] Finding all open web ports on targets...\n"
grep -RPo "80/open|443/open|8080/open" */agg.scan.gnmap | sed 's/\/agg.scan.gnmap:/:    /g' | sort -ur -k 1 | sort -t. -nk4 | tee scans/web.ports || { echo '[-] Unable to create file of identified open web ports!'; $ret 1; }

echo -e '[+] Script finished...'
