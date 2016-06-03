#!/bin/bash
# Read the config file:
source ./cluster.conf
if [ $? -ne 0 ]; then 
  echo "Cluster config file (cluster.conf not found in current directory. Please see that the file exists and is readable. Exiting."
  exit 1
fi

echo "Found cluster.conf!"

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


function DrawSeparator {
echo
echo "-------------------------------------------------------------------------------------------------------"
echo
}





DrawSeparator

## Basic functions
function SetupMaster {
  echo "Setting up Master node ..."
  echo "Copying necessary files to Master node ${MASTERIP} ..."
  scp master/etcd.conf  root@${MASTERIP}:/etc/etcd/
  scp master/local-registry.service root@${MASTERIP}:/etc/systemd/system/
  scp master/kubernetes/* root@${MASTERIP}:/etc/kubernetes/
  scp master/flanneld-conf.json root@${MASTERIP}:/root/
  DrawSeparator
  echo "Setting up Docker Local Registry ... (This may take few minutes) ..."
  echo "If the 'local-registry' container already exists on the master, the docker create command will fail (result in Conflict). That is OK! It must work the first time though!" 
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


# Call the function - SetupMaster
SetupMaster

# Ideally we should setup SKyDNS at this point on Master.


function SetupWorkerNode { 
  # Node IP is passed as a parameter. NODEIP used inside is now the local NODEIP for the scope of this function
  echo "Copying necessary files to node: $1"
  scp worker-nodes/docker root@${NODEIP}:/etc/sysconfig/
  scp worker-nodes/flanneld root@${NODEIP}:/etc/sysconfig/
  ssh root@${NODEIP} "mkdir -p /etc/systemd/system/docker.service.d/"
  scp worker-nodes/10-flanneld-network.conf root@${NODEIP}:/etc/systemd/system/docker.service.d/10-flanneld-network.conf
  # copy kubernetes files, but do a sed on NODEIP on each file on the node.
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

