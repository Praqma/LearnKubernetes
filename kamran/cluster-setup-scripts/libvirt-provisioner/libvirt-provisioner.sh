#!/bin/bash
# This script is used to provision nodes using libvirt.
# You need to be root to run this.

SCRIPT_PATH=$(dirname $0)
pushd $(pwd) > /dev/null 2>&1 
cd $SCRIPT_PATH


function my_exit() {
  # need to popd everytime I use 'exit N' , so I made a small function, which will do two things.
  # popd and exit with the error code received by this function.
  popd > /dev/null 2>&1
  exit $1

  # PS: couldn't think of a better name than 'my_exit' .
}


# First, source/load the functions 
source ./functions.sh

echo

# Then, load the cluster.conf file from the parent directory.

if [ -f ../cluster.conf ]; then
  source ../cluster.conf
else
  echolog "cluster.conf was not found in parent directory. Exiting ..."
  my_my_exit 1
fi


############### START - Perform Sanity checks on config variables #################
#
#

echo "Performing sanity checks ...."
echo

#if [ ! -f ../hosts ] ; then
if [ checkHostsFile ] ; then
  echolog "Found hosts file."
else
  echolog "You need to provide a hosts file in parent directory of this script, named 'hosts' ."
  echo "The format of hosts file is same as /etc/hosts, with extra columns:"
  echo "IP_ADDRESS	FQDN	Short_Hostname	RAM_in_MB	Disk_in_GB"
  echo
  echo "You can generate a hosts file from your /etc/hosts like so:"
  echo "egrep -v '127.0.0.1|^#'   /etc/hosts  >  hosts"
  echo
  echo "Then add the RAM and Disk columns as described above."
  my_my_exit 1
fi


if [ -z "${LIBVIRT_HOST}" ] ||  [ "${LIBVIRT_HOST}" == "localhost" ] ; then
  echolog "LIBVIRT_HOST found empty (or set to localhost). Assuming the local libvirt daemon would be used."
  # echolog "Setting LIBVIRT_CONNECTION to qemu:///system"
  LIBVIRT_CONNECTION="qemu:///system"
else
  # We have a remote host, so also check if remote user is mentioned
  if [ -z "${LIBVIRT_REMOTE_USER}" ] ; then
    echolog "LIBVIRT_REMOTE_USER found empty. Setting it to user 'root'"
    LIBVIRT_REMOTE_USER=root
  fi
  # Build the connect stringi for remote libvirt connection:
  LIBVIRT_CONNECTION="qemu+ssh://${LIBVIRT_REMOTE_USER}@${LIBVIRT_HOST}/system"
fi
echolog "Setting up libvirt connection string as: ${LIBVIRT_CONNECTION}"


if [ -z "${LIBVIRT_NETWORK_NAME}" ] ; then
  echolog "You need to provide a libvirt network name, with IP address scheme matching IPs of your k8s nodes, pecified in your hosts file."
  echo "You can do it easily using virt-manager GUI interaface. Create a NAT based network in libvirt, and when done, provide it's name as LIBVIRT_NETWORK_NAME in the config file (cluster.conf) ."
  my_my_exit 1
else
  if [ "$(virsh net-list --name | grep ${LIBVIRT_NETWORK_NAME} )" == "${LIBVIRT_NETWORK_NAME}" ] &&  [ "$(getLibvirtNetworkState ${LIBVIRT_NETWORK_NAME})" == "active" ] ; then
    echolog "Network ${LIBVIRT_NETWORK_NAME} was found in Libvirt network list, and is in 'active' state."
  else
    echolog "Network ${LIBVIRT_NETWORK_NAME} was not found in Libvirt network list. Or it is not active."
    echolog "You need to provide a libvirt network name, with IP address scheme matching IPs of your k8s nodes, pecified in your hosts file."
    echo "You can do it easily using virt-manager GUI interaface. Create a NAT based network in libvirt, and when done, provide it's name as LIBVIRT_NETWORK_NAME in the config file (cluster.conf) ."
    my_exit 1
  fi
fi

if  [ -z "${VM_DISK_DIRECTORY}" ] ; then
  echolog "VM_DISK_DIRECTORY found empty. Using the libvirt defaults for vm disks (normally /var/lib/libvirt/images/) . Expecting at least 80 GB free disk space."
else
  if [ ! -d ${VM_DISK_DIRECTORY} ] ; then
    echolog "The location provided to hold VM disks does not exist. $VM_DISK_DIRECTORY."
    echo "Please ensure that the directory exists and is owned by root:libvirt, with permissions 0775. The location needs to have at least 80 GB free disk space."
    my_exit 1
  else
    echolog "Setting up ${VM_DISK_DIRECTORY} for VM disk image storage... "
  fi
fi


# Check if INSTALL_TIME_RAM is defined and is enough
if [ -z "$INSTALL_TIME_RAM" ] ; then
  echolog "INSTALL_TIME_RAM found empty. Using 1280 (MB) as the default value."
  INSTALL_TIME_RAM=1280
else
  checkInstallTimeRAM $INSTALL_TIME_RAM > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echolog "Found problem with INSTALL_TIME_RAM: $(checkInstallTimeRAM $INSTALL_TIME_RAM) ."
    my_exit 1
  fi
fi

echolog "Using $INSTALL_TIME_RAM MB of RAM for each VM for provisioning process."


if [ -z "${HTTP_BASE_URL}" ] ; then
  echolog "HTTP_BASE_URL found empty. You need to provide the URL where the provisioner expects the cd contents of the Fedora ISO. Plus a port number in case the port is not 80."
  echo "You also need to have /cdrom and /kickstart being served through this URL."
  echo "Examples of HTTP_URL are:"
  echo "http://localhost/"
  echo "http://localhost:8080/"
  echo "http://server.example.org"
  echo "http://server.example.org:81"
  my_exit 1
else
  # Lets check if URL is reachable, and that we get a 200 responce from /cdrom and /kickstart.
  # using -k with curl as user may provide a HTTPS url in cluster.conf and that URL may have self signed certs.
  # -k works with both http and https, so using it in all curl commands.
  CURL_CODE=$(curl -k -sL -w "%{http_code}\\n" "${HTTP_BASE_URL}" -o /dev/null)
  if [ ${CURL_CODE} -eq 200 ] ; then
    echolog "HTTP_BASE_URL ( ${HTTP_BASE_URL} ) is accessible! Good. "
    # Lets check if /kickstart and /cdrom are accessible
    CURL_CODE_CDROM=$(curl -k -sL -w "%{http_code}\\n" "${HTTP_BASE_URL}/cdrom/.discinfo" -o /dev/null)
    CURL_CODE_KICKSTART=$(curl -k -sL -w "%{http_code}\\n" "${HTTP_BASE_URL}/kickstart/kickstart.template" -o /dev/null)
    if [ ${CURL_CODE_CDROM} -eq 200 ] && [ ${CURL_CODE_KICKSTART} -eq 200 ] ; then
      echo "/cdrom and /kickstart are also accessible. Hope you have content in there!"
    else
      echolog "The /cdrom and /kickstart locations were not found through HTTP_BASE_URL  ( ${HTTP_BASE_URL}  ) ."
      echo "You need to have these two locations in the document root of your web server."
      my_exit 1
    fi
  else
    echolog "The URL specified in HTTP_BASE_URL ( ${HTTP_BASE_URL} ) is not reachable!"
    my_exit 1
  fi
fi


# Need to make sure that kickstart directory exists inside the parent directory. 
# Also it needs to have a kickstart.template file in it as a minimum.

# if [ ! -f ../kickstart/kickstart.template ] ; then
if [ checkKickstart ] ; then
  echolog "kickstart file found in kickstart/kickstart.template in the parent directory."
else
  echolog "kickstart file not found as kickstart/kickstart.template ."
  echolog "You need to have the kickstart directory in the project root directory and also have the kickstart.template file in it."
  my_exit 1
fi

# checkKickstart

# Get current user's public key. This is used in the kickstart file.
if [ getUserPublicKey ] ; then
  USER_PUBLIC_KEY=$(getUserPublicKey)
  # echolog "Found current user's RSA key as: $(echo $USER_PUBLIC_KEY | cut -c -40 ) ..."
  echolog "Found current user's RSA key as: $(echo $USER_PUBLIC_KEY)"
else
  echolog "Could not find public key (of the RSA key-pair) for the current user $USER in ~/.ssh/id_rsa.pub  . Please generate a key-pair for current user, using 'ssh-keygen -t rsa' . Exiting ... "
  my_exit 1
fi



# Check if PARALLEL is set:
if [ -z "$PARALLEL" ] || [ "$PARALLEL" != "1" ] ; then
  # if empty then set parallel to zero (no)  - i.e. disable it.
  PARALLEL=0
  echolog "Parallel provisioning is disabled"
else
  # Here check if we have enough RAM to execute x number of VMs in parallel.
  # By this time, we already know the value of INSTALL_TIME_RAM , so we will use it for calculation. 
  NETWORK_OCTETS=$(getFirstThreeOctectsOfIP $(getLibvirtNetworkIP $LIBVIRT_NETWORK_NAME))
  TOTAL_VMS=$(egrep ^${NETWORK_OCTETS} ../hosts | wc -l)
  # minus 512 MB to accomodate for host system OS.
  SYSTEM_RAM=$(cat /proc/meminfo | grep MemTotal | awk '{print int($2/1000) - 512}')
  TOTAL_RAM=$(expr $INSTALL_TIME_RAM \* $TOTAL_VMS)
  if [ $TOTAL_RAM -gt $SYSTEM_RAM ] ; then
    echolog "PARALLEL is set to 1 (true/yes), and the total RAM required by all ${TOTAL_VMS} VMs (${TOTAL_RAM})is more than the installed system RAM ${SYSTEM_RAM}. This is not possible. Forcing PARALLEL=0 on run time."
    PARALLEL=0
  else
    echolog "PARALLEL is set to 1 (true/yes), and the total RAM required by all ${TOTAL_VMS} VMs (${TOTAL_RAM}) is less than the installed system RAM ${SYSTEM_RAM}. This is good. The provisioner will run in parallel."
    PARALLEL=1
  fi
fi




echo
echolog "Sanity checks complete. Proceeding to execute main program ..."
echo
echo "--------------------------------------------------------------------------------------------------"
echo



#
#
############### END - Perform Sanity checks on config variables #################





###############  START - Set system variables #####################
#
#

# Hard coded hosts file (on purpose). Expect/Need a file named 'hosts' in the parent directory.
HOSTS_FILE=../hosts

# Hard coded kickstart directory (on purpose). I expect this directory and a template file inside it.
KICKSTART_DIRECTORY=../kickstart

LIBVIRT_NETWORK_IP=$(getLibvirtNetworkIP $LIBVIRT_NETWORK_NAME)
LIBVIRT_NETWORK_MASK=$(getLibvirtNetworkMask $LIBVIRT_NETWORK_NAME)


# echo "Default Gateway for VMs belonging to this network is: ${LIBVIRT_NETWORK_IP}"
# echo "Network Mask for VMs belonging to this network is: ${LIBVIRT_NETWORK_MASK}"


# INSTALL_TIME_RAM defined in ../cluster.conf 




#
#
###############  END - Set system variables #####################



###############  START - Main program #####################
#
#

# getNodeRAM controller.example.com
# getNodeDisk controller1.example.com

THREE_OCTETS=$(getFirstThreeOctectsOfIP ${LIBVIRT_NETWORK_IP})

generateKickstartAll ${THREE_OCTETS} ${LIBVIRT_NETWORK_IP} ${LIBVIRT_NETWORK_MASK} ${USER_PUBLIC_KEY}


# echo "Running Main: createVMAll ${THREE_OCTETS} ${VM_DISK_DIRECTORY} ${LIBVIRT_NETWORK_NAME} ${HTTP_BASE_URL} ${LIBVIRT_CONNECTION}"
# createVMAll ${THREE_OCTETS} ${VM_DISK_DIRECTORY} ${LIBVIRT_NETWORK_NAME} ${HTTP_BASE_URL} ${LIBVIRT_CONNECTION} ${INSTALL_TIME_RAM} ${PARALLEL}


 
#
#
###############  END - Main program #####################
my_exit 
