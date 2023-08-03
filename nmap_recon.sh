#!/bin/bash

# Print help information if no args given, requires sudo privileges for nmap update,UDP, and aggressive scans
if [ $# -eq 0 ]; then
   echo "Usage: sudo ./nmap_recon.sh '<IP Range>'";
   exit 1;
fi

# Grab arguments and assign to variables
ip_range=$1

echo -e "Script starting...\n"

# Create needed folders and files, tee requires existing folders and files to work
echo -e "Creating necessary files and folders...\n"
mkdir scans exploits
touch scans/open_tcp.ports scans/open_udp.ports scans/web.ports exploits/technologies.txt exploits/vulners.exploits exploits/vulners.cves

# Update databases
echo -e "Updating databases...\n"
nmap --script-updatedb
searchsploit --update

# Scan for avaialble hosts on the subnet
echo -e "Starting nmap scan for available hosts...\n"
nmap -sn $ip_range -oG scans/open.hosts

# Create target file for nmap
echo -e "Created list of targets...\n"
cat scans/open.hosts| grep -v \# | cut -d " " -f2 > targets.txt

# Create folders for each found IP
echo -e "Created directories for each target...\n"
for ip in $(cat targets.txt ); do mkdir $ip; done

# For each IP, do standard script and all TCP ports, save to each IP's folder
echo -e "Starting nmap scan of all TCP ports...\n"
for ip in $(cat targets.txt ); do nmap -sC -sT -T4 -p- $ip -oA $ip/tcp.all; done

# Recursively find all found open TCP ports, format it for use with nmap, save to file
open_tcp_ports=$(grep -R open */*.gnmap | grep -Po "([\d]+/open)" | cut -d "/" -f1 | sort -un | xargs | tr " " "," | tee scans/open_tcp.ports)
echo -e "All open TCP ports:\n"$open_tcp_ports

# For each IP, do standard script and fast UDP ports, save to each IP's folder
echo -e "\nStarting nmap scan of fast UDP ports...\n"
for ip in $(cat targets.txt ); do sudo nmap -sC -sU -T4 -F $ip -oA $ip/udp.all; done 

# Recursively find all found open UDP ports, format it for use with nmap, save to file
open_udp_ports=$(grep -R open */udp.*.gnmap | grep -Po "[\d]+/open/udp" | cut -d "/" -f1 | sort -un | xargs | tr " " "," | tee scans/open_udp.ports)
echo -e "All open UDP ports:\n"$open_udp_ports

# Conduct agressive and vulnerability scan for each IP on UDP and TCP open ports
echo -e "\nStarting nmap aggressive scan of all open TCP and UDP ports...\n"
# Will alter scan if no UDP ports
if [ -z "$open_udp_ports" ]
then
	for ip in $(cat targets.txt); do sudo nmap -Pn -sT -sU -A -T4 -p $open_tcp_ports --open $ip --script vuln -oA $ip/agg.scan; done
else
	for ip in $(cat targets.txt); do sudo nmap -Pn -sT -sU -A -T4 -p U:$open_udp_ports,T:$open_tcp_ports --open $ip --script vuln -oA $ip/agg.scan; done
fi

# Display identified exploits for all targets sorted by highest CVSS and save to file
echo -e "Finding all identified exploits against targets...\n"
grep -R "*EXPLOIT*" */agg.scan.nmap | awk '{ print $1, $3, $4 }' | sed 's/\/agg.scan.nmap:|/:/g' | sort -ru -k2 | tee exploits/vulners.exploits

# Display all identified CVE's for all targets sorted by highest CVSS and save to file
echo -e "Finding all identified CVEs against targets...\n"
grep -R "CVE" */agg.scan.nmap | sort -u | grep -v mitre | sed 's/IDs:  CVE:/      /g; s/\/agg.scan.nmap:|/:/g' | sort -rn -k3 | tr -d "_" | tee exploits/vulners.cves

# Display identified software from nmap scans and save to a file
echo -e "Finding all identified software and versions for targets...\n"
grep -RPo "cpe:/a:[\w:\.]+" */agg.scan.xml | sed 's/\/agg.scan.xml:/ /g; s/:/ /g; s/_/ /g' | awk '{ $2="";$3=""; print $0 }' | sort -u -k2 | sort -t. -nk4 | tee exploits/technologies.txt

# Search for exploits on searchsploit affecting found technologies
echo -e "Searching searchsploit for exploits...\n"
cat exploits/technologies.txt | awk '{ $1=""; print $0 }' | while read line; do searchsploit $line | grep -v "No Results"; done

# Identify open web ports on targets
echo -e "Finding all open web ports on targets...\n"
grep -RPo "80/open|443/open|8080/open" */agg.scan.gnmap | sed 's/\/agg.scan.gnmap:/:    /g' | sort -ur -k 1 | tee scans/web.ports

echo "Script finished..."
