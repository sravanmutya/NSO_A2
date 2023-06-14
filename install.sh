#!/bin/bash

openrc = /home/sravan/'srmu21--kna1--Default Project 44275--rc'
tag ='srmu21'
ssh_key = ~/.ssh/id_rsa

# Checking if the required arguments are passed by the user - the openrc, the tag and the ssh_key
: ${1:?" Please specify openrc. "}
: ${2:?" Please specify the tag. "}
: ${3:?" Please specify the ssh_key. "}

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
