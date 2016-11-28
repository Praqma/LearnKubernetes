#!/bin/bash
# Ths script copies the certs into their proper location on all cluster nodes.
# It is assumed that the certs are already generated before this step.

# Perhaps we should read the main conf file here,
# , especially for the location of the hosts file.

SCRIPT_PATH=$(dirname $0)
pushd $(pwd)
cd $SCRIPT_PATH

NODEGROUP=$1


function certs_etcd () {
  # Certs in etcd nodes are in /etc/etcd/ 
  for node in $(egrep "etcd[0-9]\." /etc/hosts | grep -v \# | awk '{print $2}'); do
    echo "Processing node: ${node}"
    scp -o ConnectTimeout=2 *.pem root@${node}:/etc/etcd/
    ssh -o ConnectTimeout=2 root@${node} "systemctl restart etcd"
  done
}


function certs_controllers() {
  # Certs in Kubernetes controller  nodes are in /var/lib/kubernetes/ 
  for node in $(egrep "controller[0-9]\." /etc/hosts | grep -v \# | awk '{print $2}'); do
    echo "Processing node: ${node}"
    scp -o ConnectTimeout=2 *.pem root@${node}:/var/lib/kubernetes/
    ssh -o ConnectTimeout=2 root@${node} "systemctl restart kube-apiserver kube-scheduler kube-controller-manager"
  done
}


function certs_workers() {
  # Certs in Kubernetes worker nodes are in /var/lib/kubernetes/ 
  for node in $(egrep "worker[0-9]\." /etc/hosts | grep -v \# | awk '{print $2}'); do
    echo "Processing node: ${node}"
    scp -o ConnectTimeout=2 *.pem root@${node}:/var/lib/kubernetes/
    ssh -o ConnectTimeout=2 root@${node} "systemctl restart kubelet kube-proxy"
  done
}

function certs_lbs() {
  # Certs in Kubernetes worker nodes are in /var/lib/kubernetes/ 
  for node in $(egrep "lb[0-9]\." /etc/hosts | grep -v \# | awk '{print $2}'); do
    echo "Processing node: ${node}"
    ssh -o ConnectTimeout=2 root@${node} "mkdir -p /certs"
    scp -o ConnectTimeout=2 *.pem root@${node}:/certs/

    # There is nothing special running on lbs, which needs certs. 
    # When there will be, we will enable it in the line below
    # ssh -o ConnectTimeout=2 root@${node} "systemctl restart kubelet kube-proxy"
  done
}


case $NODEGROUP in
etcd)
  certs_etcd
  ;;
controllers)
  certs_controllers
  ;;
workers)
  certs_workers
  ;;
lbs)
  certs_lbs
  ;;
all)
  certs_etcd
  certs_controllers
  certs_workers
  certs_lbs
  ;;
*)
  echo
  echo "This script distribute the previously generated certs to the nodes."
  echo "Valid options to pass to distribute_certs.sh are: [etcd | controllers | workers | lbs | all]"
  echo "Passing nothing to the script shows this help!"
  echo 
  ;;
esac


# important to go back to the directory where we came from
popd
