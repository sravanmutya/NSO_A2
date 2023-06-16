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
  echo "$(date) No nodes to release"
fi


# Deleting the keypair corresponding to the tag
keypairs=$(openstack keypair list -f value -c Name | grep "$tag_sr*")

if [ -n "$keypairs" ]; then
  for key in $keypairs; do  
    openstack keypair delete $key
  done
  echo "$(date) Removed $sr_keypair key"
else
  echo "$(date) No keypair to delete."
fi


# Remove and detach the floating ip from virtual port
floating_ip=$(openstack floating ip list --status DOWN -f value -c "Floating IP Address")
# floating_ip_list=(${existing_floating_ip// / })

if [ -n "$floating_ip" ]; then
  for fip in $floating_ip; do
    openstack floating ip delete "$fip"
  done
  echo "$(date) Removed all floating IPs"
else
  echo "$(date) No floating IPs to remove"
fi

vip_fip=$(openstack floating ip unset --port "$fip2" )
# unsetfip=$(openstack floating ip unset )
echo "$(date) Floating IP detached from the virtual port"

vip_addr=$(openstack port show "$vip_port" -f value -c fixed_ips | grep -Po '\d+\.\d+\.\d+\.\d+')
# echo "$(date) Removed virtual IP address $vip_addr"
echo "$vip_addr" >> vipaddr

# Unassign floating IPs
unassigned_ips=$(openstack floating ip list --port "$vip_port" --status ACTIVE -f value -c "Floating IP Address")

for ip in $unassigned_ips; do
    openstack floating ip unset --port "$ip"
    echo "$(date) Unset floating IP $ip from port"
done

# Remove the virtual port
openstack port delete "$vip_port"
echo "$(date) Removed virtual port $vip_port"


# Removing the subnet
# subnet_id=$(openstack router show "$router_name" -f json -c interfaces_info | grep -oP '(?<="subnet_id": ")[^"]+' | awk '{print $1}')

subnet_id=$(openstack subnet list --tag "$tag_sr" -c ID -f value)
if [ -n "$subnet_id" ]; then
  for sub in $subnet_id; do
    openstack router remove subnet "$sr_router" "$sub"
    openstack subnet delete "$sub"
  done
  echo "$(date) Removed $sr_subnet subnet"
else
  echo "$(date) No subnets to remove"
fi

# remove_ext_gateway=$(openstack router unset --external-gateway $existing_routers) 

# Removing router
routers=$(openstack router list --tag $tag_sr -f value -c Name)
if [ -n "$routers" ]; then
  for r in $routers; do
    openstack router delete "$r"
  done
  echo "$(date) Deleted router $sr_router"
else
  echo "$(date) No routers to remove"
fi

