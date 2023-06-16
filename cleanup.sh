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


# Sourcing openrc file
echo "$cd_time Cleaning up $tag_sr using $openrc_sr"
source $openrc_sr


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
fip2="$(cat floating_ip2)"

# Retrieving the list of servers with the tag
servers=$(openstack server list --name "$tag_sr" -c ID -f value)
n=$(echo "$servers" | wc -l)
# Deleting each server
if [ -n "$servers" ]; then
  echo "$(date) We have $n nodes, releasing them"
  for server_id in $servers; do
    openstack server delete $server_id
  done
  echo "$(date) Nodes are gone"
else
  echo "$(date) No nodes to delete"
fi


# Deleting the keypair corresponding to the tag
keypairs=$(openstack keypair list -f value -c Name | grep "$tag_sr*")

if [ -n "$keypairs" ]; then
  for key in $keypairs; do  
    openstack keypair delete $key
  done
  echo "$(date) Removed $sr_keypair key"
else
  echo "$(date) $sr_keypair key does not exist."
fi
