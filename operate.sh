#!/bin/bash

# Checking if the required arguments are present - the openrc, the tag and the ssh_key
# The program will not run if these arguments are not present.
: ${1:?" Please specify the openrc, tag, and ssh_key"}
: ${2:?" Please specify the openrc, tag, and ssh_key"}
: ${3:?" Please specify the openrc, tag, and ssh_key"}


cd_time=$(date)
openrc_sr=${1}     # Fetching the openrc access file
tag_sr=${2}        # Fetching the tag for easy identification of items
ssh_key_sr=${3}    # Fetching the ssh_key for secure remote access
no_of_servers=$(grep -E '[0-9]' servers.conf) # Fetching the number of nodes from servers.conf


# Define variables
natverk_namn="${2}_network"
sr_subnet="${2}_subnet"
sr_keypair="${2}_key"
sr_router="${2}_router"
sr_security_group="${2}_security_group"
sr_haproxy_server="${2}_proxy"
sr_bastion_server="${2}_bastion"
sr_server="${2}_dev"
vip_port="${2}_vip" #virtual ip port
sshconfig="config"
knownhosts="known_hosts"
hostsfile="hosts"


run_status=0 ##ansible run status
echo "Running Operation mode for tag: $tag_name using $rc_file for credentials"
source $openrc_sr

generate_config(){
    bastionfip=$(openstack server list --name $sr_bastion_server -c Networks -f value | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==2')
    # haproxyfip=$(openstack server list --name $sr_haproxy_server -c Networks -f value | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==1')
    haproxyfip=$(openstack server show $sr_haproxy_server -c addresses | grep -Po '\d+\.\d+\.\d+\.\d+' | awk 'NR==1')
    

    echo "$(date) Generating config file"
    echo "Host $sr_bastion_server" >> $sshconfig
    echo "   User ubuntu" >> $sshconfig
    echo "   HostName $bastionfip" >> $sshconfig
    echo "   IdentityFile ~/.ssh/id_rsa" >> $sshconfig
    echo "   StrictHostKeyChecking no" >> $sshconfig
    echo "   PasswordAuthentication no" >> $sshconfig
    
    echo " " >> $sshconfig
    echo "Host $sr_haproxy_server" >> $sshconfig
    echo "   User ubuntu" >> $sshconfig
    echo "   HostName $haproxyfip" >> $sshconfig
    echo "   IdentityFile ~/.ssh/id_rsa" >> $sshconfig
    echo "   StrictHostKeyChecking no" >> $sshconfig
    echo "   PasswordAuthentication no ">> $sshconfig
    echo "   ProxyJump $sr_bastion_server" >> $sshconfig

    # generate hosts file
    echo "[bastion]" >> $hostsfile
    echo "$sr_bastion_server" >> $hostsfile
    echo " " >> $hostsfile
    echo "[HAproxy]" >> $hostsfile
    echo "$sr_haproxy_server" >> $hostsfile
    
    echo " " >> $hostsfile
    echo "[primary_proxy]" >> $hostsfile
    echo "$sr_haproxy_server" >> $hostsfile
    
    echo " " >> $hostsfile
    echo "[webservers]" >> $hostsfile

