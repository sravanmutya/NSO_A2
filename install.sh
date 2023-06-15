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


if [[ -f "$sshconfig" ]] ; then
    rm "$sshconfig"
fi

if [[ -f "$knownhosts" ]] ; then
    rm "$knownhosts"
fi

if [[ -f "$hostsfile" ]] ; then
    rm "$hostsfile"
fi

# if [[ -f "$f1" ]] ; then
#     rm "$f1"
# fi

# if [[ -f "$f2" ]] ; then
#     rm "$f2"
# fi


## Create port for Virtual IP
vip=$(openstack port create --network "$natverk_namn" --fixed-ip subnet="$sr_subnet" --no-security-group "$vip_port" )

unassigned_ips=$(openstack floating ip list --status DOWN -f value -c "Floating IP Address")


# Node creation
existing_servers=$(openstack server list --status ACTIVE --column Name -f value)

if [[ "$existing_servers" == *"$sr_bastion_server"* ]]; then
        echo "$(date) $sr_bastion_server already exists"
else
   if [[ -n "$unassigned_ips" ]]; then
        fip1=$(echo "$unassigned_ips" | awk '{print $1}')
        if [[ -n "$fip1" ]]; then
            echo "$(date) Assigned floating IP for the Bastion"
        else
            echo "$(date) Creating floating IP for the Bastion"
            created_fip1=$(openstack floating ip create ext-net -f json | jq -r '.floating_ip_address' > floating_ip1)
            fip1="$(cat floating_ip1)"
        fi
    else
            echo "$(date) Creating floating IP for the Bastion"
            created_fip1=$(openstack floating ip create ext-net -f json | jq -r '.floating_ip_address' > floating_ip1)
            fip1="$(cat floating_ip1)"
    fi
    bastion=$(openstack server create --image "Ubuntu 20.04 Focal Fossa 20200423" ${sr_bastion_server} --key-name ${sr_keypair} --flavor "1C-2GB-50GB" --network ${natverk_namn} --security-group ${sr_security_group}) 
    add_bastion_fip=$(openstack server add floating ip ${sr_bastion_server} $fip1) 
    echo "$(date) created $sr_bastion_server server"
fi


if [[ "$existing_servers" == *"$sr_haproxy_server"* ]]; then
        echo "$(date) HAproxy already exists"
else 
    if [[ -n "$unassigned_ips" ]]; then
        fip2=$(echo "$unassigned_ips" | awk '{print $2}')
        if [[ -n "$fip2" ]]; then
            echo "$(date) Created floating IP for the HAproxy server (Floating ip for Virtual IP)"
        else
            echo " $(date) Creating floating IP for the HAproxy (Floating ip for Virtual IP)"
            created_fip2=$(openstack floating ip create ext-net -f json | jq -r '.floating_ip_address' > floating_ip2)
            fip2="$(cat floating_ip2)"
        fi
    else
            echo "$(date) Creating floating ip for HAproxy (Floating ip for Virtual IP)"
            created_fip2=$(openstack floating ip create ext-net -f json | jq -r '.floating_ip_address' > floating_ip2)
            fip2="$(cat floating_ip2)"
    fi
    haproxy=$(openstack server create --image "Ubuntu 20.04 Focal Fossa 20200423" $sr_haproxy_server --key-name $sr_keypair --flavor "1C-2GB-50GB" --network $natverk_namn --security-group $sr_security_group)
    # add_haproxy_fip=$(openstack server add floating ip $sr_haproxy_server $fip2)

    echo "$(date) HAproxy server created successfully"
fi

# Attaching the floating IP to the VIP port
add_vip_fip=$(openstack floating ip set --port "$vip_port" $fip2)

vip_addr=$(openstack port show "$vip_port" -f value -c fixed_ips | grep -Po '\d+\.\d+\.\d+\.\d+')
echo "$vip_addr" >> vipaddr

# Update vip port with fp pair
update_port=$(openstack port set --allowed-address ip-address="$fip2" "$vip_port")

devservers_count=$(grep -ocP $sr_server <<< $existing_servers)


if(($no_of_servers > $devservers_count)); then
    devservers_to_add=$(($no_of_servers - $devservers_count))
    sequence=$(( $devservers_count+1 ))
    devserver_name=${dev_server}${sequence}

    while [ $devservers_to_add -gt 0 ]  
    do    
        server_output=$(openstack server create --image "Ubuntu 20.04 Focal Fossa 20200423"  $devserver_name --key-name "$sr_keypair" --flavor "1C-2GB-50GB" --network $natverk_namn --security-group $sr_security_group)
        echo "$(date) Created $devserver_name server"
        ((devservers_to_add--))
        
        active=false
        while [ "$active" = false ]; do
            server_status=$(openstack server show "$devserver_name" -f value -c status)
            if [ "$server_status" == "ACTIVE" ]; then
                active=true
            fi
        done

        sequence=$(( $sequence+1 ))
        devserver_name=${sr_server}${sequence}

    done

elif (( $no_of_servers < $devservers_count )); then
    devservers_to_remove=$(($devservers_count - $required_dev_servers))
    sequence1=0
    while [[ $sequence1 -lt $devservers_to_remove ]]; do
        server_to_delete=$(openstack server list --status ACTIVE -f value -c Name | grep -m1 -oP "${tag_sr}"'_dev([1-9]+)')   
        deleted_server=$(openstack server delete "$server_to_delete" --wait)
        echo " $(date) Deleted $server_to_delete server"
        ((sequence1++))
    done
else
    echo "Required number of dev servers($no_of_servers) already exist."
fi
