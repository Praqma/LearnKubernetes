#!/bin/bash 
# Fuctions used in provisioning scripts

function echolog() {
  echo $1 
  logger -t libvirt-provisioner $1 
}


function getLibvirtNetworkIP() {
  # Receive name of libvirt network in $1
  local NETWORK=$1
  if [ ! -z "$NETWORK" ] ; then
    local IP=$(virsh net-dumpxml ${NETWORK} | grep "ip address" | tr -d "<>\'" | awk '{print $2}'| cut -d '=' -f2)
    echo $IP
  else
    echo "Network-Name-Missing"
  fi
}


function getLibvirtNetworkMask() {
  # Receive name of libvirt network in $1
  local NETWORK=$1
  if [ ! -z "$NETWORK" ] ; then
    local MASK=$(virsh net-dumpxml ${NETWORK} | grep "ip address" | tr -d "<>\'" | awk '{print $3}'| cut -d '=' -f2)
    echo $MASK
  else
    echo "Network-Name-Missing"
  fi
}

function getNodeRAM() {
  # Receive node name in $1
  local NODE_NAME=$1
  if [ ! -z "$NODE_NAME" ] ; then
    local NODE_RAM=$(egrep "$NODE_NAME"  $HOSTS_FILE | grep -v \^#| awk '{print $4}')
    # Check if the value is actually a number
    local REGEX='^[0-9]+$'
    # Notice special syntax for this "if"
    if [[ $NODE_RAM =~ $REGEX ]] ; then
      #RAM size is in MB
      echo $NODE_RAM
    else
      echo "RAM-Size-Not-Integer"
    fi
  else
    echo "Node-Name-Missing"
  fi
}



function getNodeDisk() {
  # Receive node name in $1
  local NODE_NAME=$1
  if [ ! -z "$NODE_NAME" ] ; then
    local NODE_DISK=$(egrep "$NODE_NAME"  $HOSTS_FILE | grep -v \^#| awk '{print $5}')
    # Check if the value is actually a number
    local REGEX='^[0-9]+$'
    # Notice special syntax for this "if"
    if [[ $NODE_DISK =~ $REGEX ]] ; then
      # disk size is in GB
      echo $NODE_DISK
    else
      echo "Disk-Size-Not-Integer"
    fi
  else
    echo "Node-Name-Missing"
  fi
}


function getNodeIP() {
  # Receive node name in $1
  local NODE_NAME=$1
  if [ ! -z "$NODE_NAME" ] ; then
    local NODE_IP=$(egrep "$NODE_NAME"  $HOSTS_FILE | grep -v \^#| awk '{print $1}')
    # IP
    echo $NODE_IP
  else
    echo "Node-Name-Missing"
  fi
}


function getNodeFQDN() {
  # Receive node IP in $1 , and return Node's FQDN
  local NODE_IP=$1
  if [ ! -z "$NODE_IP" ] ; then
    local NODE_FQDN=$(egrep "$NODE_IP"  $HOSTS_FILE | grep -v \^#| awk '{print $2}')
    # Node's FQDN
    echo $NODE_FQDN
  else
    echo "Node-IP-Missing"
  fi
}


function getLibvirtNetworkState() {
  # Receive network name in $1
  local NETWORK=$1
  local NETWORK_STATE=$(virsh net-list  | grep $NETWORK | awk '{print $2}')
  echo $NETWORK_STATE
}




function checkKickstart() {
  # Need to make sure that kickstart directory exists inside the parent directory.
  # Also it needs to have a kickstart-template.ks file in it as a minimum.
  if [ -f ../kickstart/kickstart-template.ks ] ; then
    return 0
  else
    return 1
  fi
}

function checkHostsFile() {
  # checks host file exist or not.
  if [ -f ../hosts ] ; then
    return 0
  else
    return 1
  fi
}


function generateKickstartNode() {
  # Receive node name in $1
  # Receive kubernetes v-network name in $2

  local NODE_FQDN=$1
  local NODE_GATEWAY_IP=$2
  local NODE_NETMASK=$3

  local NODE_IP=$(getNodeIP $NODE_FQDN)
  local NODE_DNS=$NODE_GATEWAY_IP

  if [ checkKickstart ] ; then
    local KS_DIRECTORY=../kickstart
    local KS_TEMPLATE=${KS_DIRECTORY}/kickstart-template.ks
    sed -e "s/NODE_IP/${NODE_IP}/" \
        -e "s/NODE_NETMASK/${NODE_NETMASK}/" \
        -e "s/NODE_FQDN/${NODE_FQDN}/" \
        -e "s/NODE_GATEWAY/${NODE_GATEWAY_IP}/" \
        -e "s/NODE_DNS/${NODE_DNS}/" \
      ${KS_TEMPLATE} > ${KS_DIRECTORY}/${NODE_FQDN}.ks 
  else
    echo "Kickstart-Directory-or-File-Problem."
  fi
}

function getFirstThreeOctectsOfIP() {
  local IP=$1
  echo $IP | cut -d '.' -f -3
}

function generateKickstartAll() {
  # receive THREE_OCTETS as $1 
  # receive NETWORK_GATEWAY_IP as $2
  local THREE_OCTETS=$1
  local NETWORK_GATEWAY_IP=$2
  local NETWORK_MASK=$3

  # This generates kickstart for all nodes

  if [ checkHostsFile ] ; then
    # Here we generate kickstart files,
    for node in $(grep "$THREE_OCTETS" ../hosts | grep -v \^# | awk '{print $2}'); do
      echo "generateKickstartNode $node $NETWORK_GATEWAY_IP $NETWORK__MASK"
    done
  fi
}

