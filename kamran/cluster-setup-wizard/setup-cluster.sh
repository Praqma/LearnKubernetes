#!/bin/bash
# Read the config file:
source ./cluster.conf
if [ $? -ne 0 ]; then 
  echo "Cluster config file (cluster.conf) not found in current directory. Please see that the file exists and is readable. Exiting."
  exit 1
fi


echo "Found cluster.conf!"

##### START - Functions used in the script ###################################################################

function CheckConfigVariables {

  # Check for required variables:

  if [ -z "$MASTERIP" ]; then
    echo "MASTERIP is not defined. Exiting."
    exit 1
  else
    echo "Found MASTERIP as ${MASTERIP}"
  fi

  if [ -z "${NODE_START_OCTET}" ]; then
    echo "NODE_START_OCTET is not defined. Exiting."
    exit 1
  else
    echo "Found NODE_START_OCTET as ${NODE_START_OCTET}"
  fi


  if [ -z "${NODE_END_OCTET}" ]; then
    echo "NODE_END_OCTET is not defined. Exiting."
    exit 1
  else
    echo "Found NODE_END_OCTET as ${NODE_END_OCTET}"
  fi

  if [ -z "${NODE_ORDINARY_USER}" ]; then
    echo "NODE_ORDINARY_USER is not defined. Exiting."
    exit 1
  else
    echo "Found NODE_ORDINARY_USER as ${NODE_ORDINARY_USER}"
  fi


  if [ -z "${CLUSTER_NETWORK_ADDRESS}" ] ; then
    echo "CLUSTER_NETWORK_ADDRESS -or- CLUSTER_NETWORK_MASKBITS is not defined. Exiting."
    exit 1
  else
    echo "Found CLUSTER_NETWORK_ADDRESS as ${CLUSTER_NETWORK_ADDRESS} / ${CLUSTER_NETWORK_MASKBITS}"
  fi

  if [ -z "${FLANNEL_NETWORK_ADDRESS}" ] ; then
    echo "FLANNEL_NETWORK_ADDRESS  -or- FLANNEL_NETWORK_MASKBITS is not defined. Exiting."
    exit 1
  else
    echo "Found FANNEL_NETWORK_ADDRESS as ${FLANNEL_NETWORK_ADDRESS} / ${FLANNEL_NETWORK_MASKBITS}"
  fi

  # also check for mask bits. 
}


CheckConfigVariables


function DrawSeparator {
  echo
  echo "-------------------------------------------------------------------------------------------------------"
  echo
}



function ConfigureOSonAllNodes {
  NODE=$1
  # This function will do several small things on each node, such as disable SELINUX, update node OS, etc.

  # Setup SSH key for user root. Copy the authorized keys file from user fedora to root.
  # Once the ORDINARY user's authorized_keys file is copied to the root user, we can connect to the nodes directly as root.  
  echo "Copying user ssh key to root ..." 
  ssh ${NODE_ORDINARY_USER}@${NODE} "sudo cp /home/${NODE_ORDINARY_USER}/.ssh/authorized_keys /root/.ssh/authorized_keys"

  echo "Disabling SELinux on node: ${NODE}"
  ssh root@${NODE} "sed -i \"s/^SELINUX=.*$/SELINUX=disabled/\"   /etc/selinux/config"

  echo "Updating OS on the node: $NODE"
  ssh root@${NODE} "rpm-ostree upgrade"

  # Reboot the nodes for the first time.
  if [ -r /tmp/${NODE}.rebooted ]; then 
    echo "This node ${NODE} is already rebooted. Proceeding with other configuration. If you want the nodes to reboot, you have to remove /tmp/*.rebooted on your development machine, from where you are running this setup-cluster.sh script."
  else
    touch /tmp/${NODE}.rebooted 
    ssh root@${NODE} "systemctl reboot"
  fi
}


function SetupMaster {
  echo "Setting up Kubernetes components on Master node ..."
  echo "Copying necessary files to Master node ${MASTERIP} ..."
  scp master/etcd.conf  root@${MASTERIP}:/etc/etcd/
  scp master/local-registry.service root@${MASTERIP}:/etc/systemd/system/

  # Do magic with apiserver file. The / causes problem with sed, so I had to break it into two pieces and then join them with escaped '/'.
  # Then copy file to master node.
  CLUSTER_NETWORK="${CLUSTER_NETWORK_ADDRESS}\/${CLUSTER_NETWORK_MASKBITS}"
  sed -e "s/CLUSTER_NETWORK/${CLUSTER_NETWORK}/g"  -e "s/MASTERIP/${MASTERIP}/g"  master/kubernetes/apiserver > /tmp/master-apiserver
  scp /tmp/master-apiserver  root@${MASTERIP}:/etc/kubernetes/apiserver

  # Do magic with sed and then copy the config file to master.
  sed -e "s/MASTERIP/${MASTERIP}/g"  master/kubernetes/config > /tmp/master-config
  scp /tmp/master-config  root@${MASTERIP}:/etc/kubernetes/config


  # Do sed magic with flannel and then copy the file.
  FLANNEL_NETWORK="${FLANNEL_NETWORK_ADDRESS}\/${FLANNEL_NETWORK_MASKBITS}"
  sed "s/FLANNEL_NETWORK/${FLANNEL_NETWORK}/g" master/flanneld-conf.json > /tmp/flanneld-conf.json 
  scp /tmp/flanneld-conf.json root@${MASTERIP}:/root/

  DrawSeparator

  echo "Setting up Docker Local Registry ... This may take few minutes ..."
  echo "If the \'local-registry\' container already exists on the master, the docker create command will fail. i.e. result in Conflict. That is OK! It must work the first time though!" 
  ssh root@${MASTERIP} \
      "docker create -p 5000:5000 \
      -v /var/lib/local-registry:/var/lib/registry \
      -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry \
      -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
      --name=local-registry registry:2"

  ssh root@${MASTERIP} "systemctl daemon-reload"
  ssh root@${MASTERIP} "systemctl enable local-registry"
  ssh root@${MASTERIP} "systemctl restart local-registry"
  echo "Verify that the local-registry container is running ..."
  ssh root@${MASTERIP} "docker ps"
  DrawSeparator
  echo "Starting Kubernetes (master) services ..."
  ssh root@${MASTERIP} "systemctl enable etcd kube-apiserver kube-controller-manager kube-scheduler"
  ssh root@${MASTERIP} "systemctl restart etcd kube-apiserver kube-controller-manager kube-scheduler"
  DrawSeparator
  echo "Verify that the services on master are running ... (docker, etcd, local-registry, kube-apiserver, kube-controller-manager, kube-scheduler"
  echo "Look for the status as: 'loaded active running'"
  ssh root@${MASTERIP} "systemctl | grep service | grep  running | egrep 'docker|etcd|kube|registry'"
  DrawSeparator
  echo "Setup key for overlay network in etcd ... "
  ssh root@${MASTERIP} "curl -L http://localhost:2379/v2/keys/atomic01/network/config -XPUT --data-urlencode value@flanneld-conf.json"
  DrawSeparator
  echo "Verify that the overlay network key exists ..."
  ssh root@${MASTERIP} "curl -L --silent http://localhost:2379/v2/keys/atomic01/network/config | python -m json.tool"
}


function SetupWorkerNode { 
  # Node IP is passed as a parameter. NODEIP used inside is now the local NODEIP for the scope of this function
  echo "Copying necessary files to node: $1"
  echo "Copying defaults file for docker ..."
  sed -e "s/MASTERIP/${MASTERIP}/g"  worker-nodes/docker > /tmp/worker-docker
  scp /tmp/worker-docker root@${NODEIP}:/etc/sysconfig/docker

  echo "Copying defaults file for flannel ..."
  sed -e "s/MASTERIP/${MASTERIP}/g"  worker-nodes/flanneld > /tmp/worker-flanneld
  scp /tmp/worker-flanneld root@${NODEIP}:/etc/sysconfig/flanneld

  echo "Setting up flannel drop-in for docker service ..."
  ssh root@${NODEIP} "mkdir -p /etc/systemd/system/docker.service.d/"
  scp worker-nodes/10-flanneld-network.conf root@${NODEIP}:/etc/systemd/system/docker.service.d/10-flanneld-network.conf

  # copy kubernetes files, but do a sed on NODEIP on each file because these files are unique for each node.
  sed -e "s/MASTERIP/$MASTERIP/g" -e "s/NODEIP/$NODEIP/g"  worker-nodes/kubernetes/kubelet > /tmp/kubelet.${NODEIP} 
  scp /tmp/kubelet.${NODEIP} root@${NODEIP}:/etc/kubernetes/kubelet

  sed -e "s/MASTERIP/$MASTERIP/g" -e "s/NODEIP/$NODEIP/g"  worker-nodes/kubernetes/config > /tmp/config.${NODEIP} 
  scp /tmp/config.${NODEIP} root@${NODEIP}:/etc/kubernetes/config
  DrawSeparator
  echo "Enabling services on worker node: $NODEIP "
  ssh root@${NODEIP}  "systemctl daemon-reload; systemctl enable docker flanneld kubelet kube-proxy; systemctl restart docker flanneld kubelet kube-proxy"
  echo "Verify that the services are running on worker node. Look for: docker, flanneld, kubelet, kube-proxy"
  echo "Look for the status as: 'loaded active running'"
  ssh root@${NODEIP} "systemctl | grep service | grep  running | egrep 'docker|flanneld|kubelet|kube-proxy'"
}


function CheckConnectivity {
  REMOTESERVER=$1
  REMOTESSHPORT=22
  echo "Checking SSH connectivity to $REMOTESERVER"
  2>/dev/null >/dev/tcp/${REMOTESERVER}/${REMOTESSHPORT}
  if [ $? -ne 0 ]; then
    echo "Remote server: ${REMOTESERVER} was not reachable on SSH (port ${REMOTESSHPORT})."
    return 9
  else
    echo "Success connecting to ${REMOTESERVER} on port ${REMOTESSHPORT}"
    # return command returns the status code to the calling program. Bash functions do not support returning values.
    return 0
  fi
}


##### END - Functions used in the script ###################################################################

CheckConfigVariables

DrawSeparator

echo "Checking for first time connectivity to all nodes (Master and worker) ..."
CheckConnectivity $MASTERIP

if [ $? -ne 0 ]; then
  echo "Master node: $MASTERIP was not reachable on port 22. Exiting setup."
  exit 1
fi

for i in $(seq $NODE_START_OCTET $NODE_END_OCTET); do 
  # Generate NODEIP here.
  NODEIP=${NODE_NET_ADDRESS}.${i}
  CheckConnectivity ${NODEIP}
  if [ $? -ne 0 ]; then
    echo "Worker node: $NODEIP:  was not reachable on port 22. Exiting setup."
    exit 1
  fi
done


DrawSeparator

echo "Configure OS on master and nodes. This involves rebooting the nodes too - for the first time."

# Configure OS on MASTER
echo "Setting up OS on Master: $MASTERIP"
ConfigureOSonAllNodes ${MASTERIP}

# Configure OS on NODES
for i in $(seq $NODE_START_OCTET $NODE_END_OCTET); do 
  # Generate NODEIP here.
  DrawSeparator
  NODEIP=${NODE_NET_ADDRESS}.${i}
  echo "Setting up OS on node: ${NODEIP}"
  ConfigureOSonAllNodes ${NODEIP}
done

DrawSeparator

echo "Since nodes might have been rebooted, we wait for them to come back online..."
echo "debug - reboot nodes now - sleep 5"
sleep 5


echo "Checking if node $MASTERIP came back up after reboot."
LIFEPROBE=99
while [ $LIFEPROBE -ne 0 ]; do 
  CheckConnectivity $MASTERIP
  LIFEPROBE=$?
  sleep 1
done



for i in $(seq $NODE_START_OCTET $NODE_END_OCTET); do 
  DrawSeparator
  echo "Checking if node $NODEIP came back up after reboot."
  LIFEPROBE=99
  while [ $LIFEPROBE -ne 0 ]; do
    # Generate NODEIP here.
    NODEIP=${NODE_NET_ADDRESS}.${i}
    CheckConnectivity ${NODEIP}
    LIFEPROBE=$?
    sleep 1
  done
done

DrawSeparator
echo "Proceeding to setup the cluster ..."

# Call the function - SetupMaster to setup Kubernetes on master. 
SetupMaster




# Call the function "SetupWorkerNode" for each node, in a loop.
for i in $(seq $NODE_START_OCTET $NODE_END_OCTET); do 
  DrawSeparator
  NODEIP=${NODE_NET_ADDRESS}.${i}
  echo "Setting up node address: ${NODEIP}"
  SetupWorkerNode $NODEIP
done 


echo "At this point you should have your nodes show up in kubectl get nodes on the master node."
ssh root@${MASTERIP} "kubectl get nodes"

echo "Reboot worker nodes to verify that they work as intended. Check 'kubectl get nodes' after X  minutes."
for i in $(seq $NODE_START_OCTET $NODE_END_OCTET); do
  DrawSeparator
  NODEIP=${NODE_NET_ADDRESS}.${i}
  echo "Rebooting node: ${NODEIP}"
  ssh root@${NODEIP} "systemctl reboot"
done



# Ideally we should setup SKyDNS at this point on Master.
