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

    # Retrieving the list of servers that are running
    active_servers=$(openstack server list --status ACTIVE -f value -c Name | grep -oP "${tag_sr}"'_dev([1-9]+)')
    echo "$active_Servers"
    # Retrieving the IP address of each server
    for server in $active_servers; do
            ip_address=$(openstack server list --name $server -c Networks -f value | grep -Po  '\d+\.\d+\.\d+\.\d+')
            echo " " >> $sshconfig
            echo "Host $server" >> $sshconfig
            echo "   User ubuntu" >> $sshconfig
            echo "   HostName $ip_address" >> $sshconfig
            echo "   IdentityFile ~/.ssh/id_rsa" >> $sshconfig
            echo "   UserKnownHostsFile=~/dev/null" >> $sshconfig
            echo "   StrictHostKeyChecking no" >> $sshconfig
            echo "   PasswordAuthentication no" >> $sshconfig
            echo "   ProxyJump $sr_bastion_server" >> $sshconfig 

            echo "$server" >> $hostsfile
    done

    echo " " >> $hostsfile
    echo "[all:vars]" >> $hostsfile
    echo "ansible_user=ubuntu" >> $hostsfile
    echo "ansible_ssh_private_key_file=~/.ssh/id_rsa" >> $hostsfile
    echo "ansible_ssh_common_args=' -F $sshconfig '" >> $hostsfile
}


delete_config(){
    if [[ -f "$hostsfile" ]] ; then
    rm "$hostsfile"
    fi
        
    if [[ -f "$sshconfig" ]] ; then
        rm "$sshconfig"
    fi
    
}


while true
do
    echo "$(date) Reading server.conf, we need $no_of_servers nodes"

    existing_servers=$(openstack server list --status ACTIVE --column Name -f value)
    devservers_count=$(grep -c $sr_server <<< $existing_servers)
    echo "$(date) Checking solution, we have: $devservers_count nodes. Sleeping."
    
    total_servers=$(openstack server list --column Name -f value)
    total_count=$(grep -c $dev_server <<< $total_servers)

    if (($no_of_servers > $devservers_count)); then
        devservers_to_add=$(($no_of_servers - $devservers_count))
        echo "$(date) Creating $devservers_to_add more nodes ..."
        sequence=$(( $total_count+1 ))
        devserver_name=${dev_server}${sequence}
