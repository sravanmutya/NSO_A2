#!/bin/bash

# Checking if the required arguments are passed by the user - the openrc, the tag and the ssh_key
: ${1:?" Please specify openrc. "}
: ${2:?" Please specify the tag. "}
: ${3:?" Please specify the ssh_key. "}

# Taking input arguments and storing them into variables
# Following naming convention of using p at the end of the variable meaning for project.
openrc_p=${1}
tag_p=${2}
ssh_key_p=${3}
