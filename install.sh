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


# Begin deployment by sourcing the given openrc file
echo "$cd_time Starting deployment of $tag_sr using $openrc_sr for credentials."
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


# Check if keypair exists
existing_keypairs=$(openstack keypair list -f value --column Name)
if echo "$existing_keypairs" | grep -qFx $sr_keypair; then
    echo "$(date) $sr_keypair already exists"
else
    # Create Keypair
    created_keypair=$(openstack keypair create --public-key $publickey "$sr_keypair" )
    echo "$(date) Created keypair $sr_keypair"
fi


# Check if network already exists
existing_networks=$(openstack network list --tag "$tag_sr" --column Name -f value)

if echo "$existing_networks" | grep -qFx $natverk_namn; then
    echo "$(date) $natverk_namn already exists"
else
    # Create network
    created_network=$(openstack network create --tag "$tag_sr" "$natverk_namn" -f json)
    echo "$(date) Created network $natverk_namn"
fi

# Check if subnet already exists
existing_subnets=$(openstack subnet list --tag "$tag_sr" --column Name -f value)

if echo "$existing_subnets" | grep -qFx $sr_subnet; then
    echo "$(date) $sr_subnet already exists"
else
    # Create network
    created_subnet=$(openstack subnet create --subnet-range 10.10.0.0/24 --allocation-pool start=10.10.0.2,end=10.10.0.30 --tag "$tag_sr" --network "$natverk_namn" "$sr_subnet" -f json)
    echo "$(date) Created subnet $sr_subnet"
fi

# check if router already exists
existing_routers=$(openstack router list --tag "$tag_sr" --column Name -f value)
if echo "$existing_routers" | grep -qFx $sr_router; then
    echo "$(date) $sr_router already exists"
else
    created_router=$(openstack router create --tag $tag_sr $sr_router )
    echo "$(date) Created router $sr_router"
    # Add subnet and external gateway to the router
    set_gateway=$(openstack router set --external-gateway ext-net $sr_router)
    add_subnet=$(openstack router add subnet $sr_router $sr_subnet)
fi

# check if security group already exists
existing_security_groups=$(openstack security group list --tag $tag_sr -f value)
# create security group
if [[ -z "$existing_security_groups" ||  "$existing_security_groups" != *"$sr_security_group"* ]]
then
    created_security_group=$(openstack security group create --tag $tag_sr $sr_security_group -f json)
    rule1=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 22 --protocol tcp --ingress $sr_security_group)
    rule2=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 80 --protocol icmp --ingress $sr_security_group)
    rule3=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 5000 --protocol tcp --ingress $sr_security_group)
    rule4=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 8080 --protocol tcp --ingress $sr_security_group)
    rule5=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 6000 --protocol udp --ingress $sr_security_group)
    rule6=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 9090 --protocol tcp --ingress $sr_security_group)
    rule7=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 9100 --protocol tcp --ingress $sr_security_group)
    rule8=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 3000 --protocol tcp --ingress $sr_security_group)
    rule9=$(openstack security group rule create --remote-ip 0.0.0.0/0 --dst-port 161 --protocol udp --ingress $sr_security_group)
    rule10=$(openstack security group rule create --protocol 112 $sr_security_group) #VVRP protocol

    echo "$(date) Created security group $sr_security_group"
else
    echo "$(date) $sr_security_group already exists"
fi


# Creation of the network, router, subnet
openstack network create srmu21_network -f json --tag srmu
openstack router create srmu21_router --tag srmu
openstack subnet create --subnet-range 192.168.0.0/24 --allocation-pool start=192.168.0.2,end=192.168.0.20 --network srmu21_network srmu21_subnet
openstack subnet set --tag srmu srmu21_subnet
openstack router add subnet srmu21_router srmu21_network
openstack router set --external-gateway ext-net srmu21_router
openstack floating ip create ext-net -f json | jq -r '.floating_ip_address' > floating_ip
echo "Floating IP: $(cat floating_ip)"

# Creation of server
openstack server create \
--flavor b.1c1gb (2ed4fefe-132e-4eaf-9351-f6b950a3d015) \
--image e6cbd963-8c28-4551-a837-e3b85da5d7a1 \
--security-group TATTA \
--nic net-id=6d6f1cf7-c4f9-4675-a3a6-6df9baa7e42b,v4-fixed-ip='192.168.0.5' \
--key-name ansible
sleep 15s
openstack server add floating ip $name $floating_ip

# openstack floating ip delete $(cat floating_ip)
# openstack router unset --external-gateway srmu21_router
# openstack router remove subnet srmu21_router srmu21_subnet
# openstack router delete srmu21_router
# openstack subnet delete srmu21_subnet
# openstack network delete srmu21_network
