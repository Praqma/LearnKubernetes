#!/bin/bash
# Summary: Install and configure Kubernetes software on controller nodes.
# Software required from fedora repo: pacemaker corosync pcs psmisc nginx 

SCRIPT_PATH=$(dirname $0)
pushd $(pwd)
cd $SCRIPT_PATH


echo "======================= Configuring Kubernetes software and PCS on controller nodes ... ======================"


# check if certs are there 
if [ ! -f ../certs/kubernetes.pem ] || [ ! -f ../certs/kubernetes-key.pem ]  || [ ! -f ../certs/ca.pem ] ; then
  echo "Certs not found in ../certs . Cannot continue ..."
  popd
  exit 9
fi

chmod +x configure*.sh


# Kubernetes software is large in size so it is better to download it on technician computer
# , and then copy it to both nodes. This saves time.

echo "Downloading Kubernetes software components to the technician computer..."
curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-apiserver
curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-controller-manager
curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-scheduler
curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kubectl

chmod +x kube* 


# List and process actual nodes and not the VIP
for node in $(grep -v \# /etc/hosts| grep "controller[0-9]"  | awk '{print $2}'); do
  echo "-------------------- Setting up Kubernetes on node: ${node}"

  echo "Copying certs ..."
  scp ../certs/*.pem root@${node}:/root/

  echo "Copying configure scripts  ..."
  scp configure-controllers-k8s.sh configure-controllers-HA.sh root@${node}:/root/

  echo "Transferring Kubernetes software components to controller nodes directly in /usr/bin/ ..."
  scp kube-apiserver kube-controller-manager kube-scheduler kubectl root@${node}:/usr/bin/
  # Note: It is OK to get a Text file busy error. It means that the binary on target already exists and is already in use.

  echo "Running the configure-controller-k8s.sh script on node"
  ssh root@${node} "/root/configure-controllers-k8s.sh"

  echo "-------------------- Setting up HA software (PCS)  on node: ${node}"

  echo "(pre)Installing HA software: pacemaker corosync pcs psmisc nginx ..."
  ssh root@${node} "yum -q -y install pacemaker corosync pcs psmisc nginx"

  # Firewalld is such a pain in the neck, that I decided to forcibly remove it and stop the iptables,
  #   to make sure that it does not interfere withe the cluster. This is VERY important.
  ssh root@${node} "systemctl stop iptables firewalld ; yum -q -y remove firewalld; iptables -t nat -F ; iptables -F"


  echo 
  echo "(pre)Enabling HA service: PCSD ..."
  echo
  ssh root@${node} "systemctl enable pcsd.service; systemctl stop pcsd.service; systemctl start pcsd.service"
  
  echo
  echo "===================================================================================================="
  echo

done




echo "======================= Configuring HA on controller nodes ... ======================"

# We have a hostname for the Virtual / Floating IP we will be using on this HA cluster. i.e. controller.example.com, with a IP (or VIP) `10.240.0.20` . This is the IP which the worker nodes will use to contact the controller/API server.

# List and process actual nodes and not the VIP
for node in $(grep -v \# /etc/hosts| grep "controller[0-9]"  | awk '{print $2}'); do
  echo "--------------------- Configuring HA on controller node: ${node}"
  # The script is already copied in the previous step (i.e. in the loop above)
  ssh root@${node} "/root/configure-controllers-HA.sh"
done



# All done. now cange directory to the same place we came from.
popd


