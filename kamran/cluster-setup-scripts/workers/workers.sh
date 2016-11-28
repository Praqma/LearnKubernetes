#!/bin/bash
# Summary: Install and configure Kubernetes software on controller nodes.
# Software required from fedora repo: pacemaker corosync pcs psmisc nginx 

SCRIPT_PATH=$(dirname $0)
pushd $(pwd)
cd $SCRIPT_PATH


echo "======================= Configuring Docker and Kubernetes software on controller nodes ... ======================"


# check if certs are there 
if [ ! -f ../certs/kubernetes.pem ] || [ ! -f ../certs/kubernetes-key.pem ]  || [ ! -f ../certs/ca.pem ] ; then
  echo "Certs not found in ../certs . Cannot continue ..."
  popd
  exit 9
fi




chmod +x configure*.sh


# Kubernetes software is large in size so it is better to download it on technician computer
# , and then copy it to both nodes. This saves time.

echo "Downloading Docker and Kubernetes software components to the technician computer..."

curl -# -z docker-1.12.3.tgz -O https://get.docker.com/builds/Linux/x86_64/docker-1.12.3.tgz

curl -# -z kubectl -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kubectl
curl -# -z kube-proxy -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-proxy
curl -# -z kubelet -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kubelet
curl -# -O https://storage.googleapis.com/kubernetes-release/network-plugins/cni-amd64-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz

chmod +x kube* 


# List and process actual nodes and not the VIP
for node in $(grep -v \# /etc/hosts| grep "worker[0-9]"  | awk '{print $2}'); do
  echo "-------------------- Setting up Kubernetes on node: ${node}"

  echo "Copying /etc/hosts file ..."
  scp /etc/hosts root@${node}:/etc/hosts

  echo "Copying certs ..."
  scp ../certs/*.pem root@${node}:/root/

  echo "Copying configure scripts  ..."
  scp configure-workers.sh root@${node}:/root/

  echo "Transferring Kubernetes software components to controller nodes directly in /usr/bin/ ..."
  scp kube*   root@${node}:/root/
  scp *.tar.gz *.tgz  root@${node}:/root/
  
  echo "Note: It is OK to get a Text file busy error. It means that the binary on target already exists and is already in use."

  echo "Running the configure-controller-k8s.sh script on node"
  ssh root@${node} "/root/configure-workers.sh"

  echo
  echo "===================================================================================================="
  echo

done


CONTROLLER_VIP=$(grep -v \# /etc/hosts | grep "controller\." | awk '{print $1}')

echo "Node status from Kubernetes... "
sleep 5
ssh root@${CONTROLLER_VIP} "kubectl get nodes"

echo "Routing information so you can setup correct routing..."
for node in $(grep -v \# /etc/hosts| grep "worker[0-9]"  | awk '{print $2}'); do
  ssh root@${CONTROLLER_VIP} \
    "kubectl describe node ${node}"  \
    | egrep -w "Name:|PodCIDR" | tr '\n' '\t' | awk '{print "Pod (CNI/CIDR) Network ",$4," is reachable via host ",$2 }'
done



# All done. now cange directory to the same place we came from.
popd


