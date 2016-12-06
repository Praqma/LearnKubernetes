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
  # Also it needs to have a kickstart.template file in it as a minimum.
  if [ -f ../kickstart/kickstart.template ] ; then
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
  local USER_PUBLIC_KEY=$4

  local NODE_IP=$(getNodeIP $NODE_FQDN)
  local NODE_DNS=$NODE_GATEWAY_IP

  if [ checkKickstart ] ; then
    local KS_DIRECTORY=../kickstart
    local KS_TEMPLATE=${KS_DIRECTORY}/kickstart.template
    sed -e "s/NODE_IP/${NODE_IP}/" \
        -e "s/NODE_NETMASK/${NODE_NETMASK}/" \
        -e "s/NODE_FQDN/${NODE_FQDN}/" \
        -e "s/NODE_GATEWAY/${NODE_GATEWAY_IP}/" \
        -e "s/NODE_DNS/${NODE_DNS}/" \
        -e "s/USER_PUBLIC_KEY/${USER_PUBLIC_KEY}/" \
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
  # receive NETWORK_MASK as $3
  local THREE_OCTETS=$1
  local NETWORK_GATEWAY_IP=$2
  local NETWORK_MASK=$3

  # This generates kickstart for all nodes

  if [ checkHostsFile ] ; then
    # Here we generate kickstart files,
    # ignore lines with '-' in them
    for node in $(grep "$THREE_OCTETS" ../hosts | egrep -v "\^#|\-" | awk '{print $2}'); do
      # list of parametes passed to generateKickstartNode are:
      # Node FQDN , Network Gateway IP, Network Mask 
      echolog "Running: generateKickstartNode $node $NETWORK_GATEWAY_IP $NETWORK_MASK"
      generateKickstartNode $node $NETWORK_GATEWAY_IP $NETWORK_MASK
    done
  else
    echolog "Hosts file could not be read. Something is wrong."
  fi
}

function createVM() {
  # This function creates the actul VM
  local NODE_NAME=$1
  local VM_DISK_DIRECTORY=$2
  local VM_NETWORK_NAME=$3
  local HTTP_BASE_URL=$4
  local LIBVIRT_CONNECTION=$5
  local INSTALL_TIME_RAM=$6

  local VM_RAM=$(getNodeRAM ${NODE_NAME})
  local VM_DISK=$(getNodeDisk ${NODE_NAME})


  virt-install --connect ${LIBVIRT_CONNECTION} -n ${NODE_NAME} --description "$NODE_NAME" --hvm \
       --cpu host --os-type Linux  --os-variant fedora22  \
      --ram $INSTALL_TIME_RAM  --vcpus 1  --features acpi=on,apic=on  --clock offset=localtime  \
      --disk path=${VM_DISK_DIRECTORY}/${NODE_NAME}.qcow2,bus=virtio,size=${VM_DISK}  \
      --network network=${VM_NETWORK_NAME}  \
      --location ${HTTP_BASE_URL}/cdrom --extra-args "ks=${HTTP_BASE_URL}/kickstart/${NODE_NAME}.ks" \
      --noreboot

  echo "Reducing the VM ${NODE_NAME} RAM to ${VM_RAM} ..."  
  virt-xml --connect ${LIBVIRT_CONNECTION}  ${NODE_NAME} --edit --memory ${VM_RAM},maxmemory=${VM_RAM}

}

function createVMAll() {
  # This function creates the VMs by calling another function 'createVM' 

  # receive THREE_OCTETS as $1 to create list of nodes from hosts file.
  # receive VM_DISK_DIRECTORY as $2
  # receive VM Network Name as $3
  # HTTP_BASE_URL as $4
  
  local THREE_OCTETS=$1
  local VM_DISK_DIRECTORY=$2
  local VM_NETWORK_NAME=$3
  local HTTP_BASE_URL=$4
  local LIBVIRT_CONNECTION=$5
  local INSTALL_TIME_RAM=$6
  local PARALLEL=$7

  # This creates VMs for all nodes

  
  # echo "THREE_OCTETS ====== ${THREE_OCTETS}"
  # echo "VM_DISK_DIRECTORY ========= ${VM_DISK_DIRECTORY} "
  # echo "VM_NETWORK_NAME  ========== ${VM_NETWORK_NAME} "
  # echo "HTTP_BASE_URL ======== ${HTTP_BASE_URL}"
  # echo "LIBVIRT_CONNECTION ======== ${LIBVIRT_CONNECTION}"

  if [ checkHostsFile ] ; then
    # Here we use the generated kickstart files, to create VMs.
    # ignore lines with '-' in them
    for node in $(grep "$THREE_OCTETS" ../hosts | egrep -v "\^#|\-" | awk '{print $2}'); do
      # list of parametes passed to generateKickstartNode are:
      # Node FQDN , Network Gateway IP, Network Mask
      echolog "Calling: createVM $node $VM_DISK_DIRECTORY $VM_NETWORK_NAME ${HTTP_BASE_URL} ${LIBVIRT_CONNECTION} ${INSTALL_TIME_RAM}"

      if [ $PARALLEL -eq 1 ] ; then
        # Notice the & for parallel
        createVM  $node i$VM_DISK_DIRECTORY $VM_NETWORK_NAME $HTTP_BASE_URL ${LIBVIRT_CONNECTION} ${INSTALL_TIME_RAM} &
        sleep 1
      else
        createVM  $node $VM_DISK_DIRECTORY $VM_NETWORK_NAME $HTTP_BASE_URL ${LIBVIRT_CONNECTION} ${INSTALL_TIME_RAM}
      fi 
    
      # wait here for parallel/child/background processes to finish
      wait

    done
  else
    echolog "Hosts file could not be read. Something is wrong."
  fi
 
}


function getUserPublicKey() {
  if [ -f ~/.ssh/id_rsa.pub ]; then
    local USER_PUBLIC_KEY=$(grep -v \# ~/.ssh/id_rsa.pub | grep -v ^$)
    echo "${USER_PUBLIC_KEY}"
    return 0
  else
    echo "Publuc-Key-Not-Found"
    return 1
  fi
}


function checkInstallTimeRAM() {
  local INSTALL_TIME_RAM=$1
  local REGEX='^[0-9]+$'
  # Notice special syntax for this "if"
  if [[ ${INSTALL_TIME_RAM} =~ $REGEX ]] ; then
    # It is a number! good!
    if [ ${INSTALL_TIME_RAM} -lt 1280 ] ; then
       echo "Install-Time-RAM-Not-Enough"
       return 1
    else
       echo $INSTALL_TIME_RAM
       return 0
    fi
  else
    echo "Install-Time-RAM-Size-Not-Integer"
    return 1
  fi

}





