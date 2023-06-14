#!/bin/bash

# Checking if the required arguments are passed by the user - the openrc, the tag and the ssh_key
: ${1:?" Please specify openrc. "}
: ${2:?" Please specify the tag. "}
: ${3:?" Please specify the ssh_key. "}
