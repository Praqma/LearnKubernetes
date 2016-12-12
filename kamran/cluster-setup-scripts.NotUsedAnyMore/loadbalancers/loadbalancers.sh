#!/bin/bash
# prepares lb nodes

SCRIPT_PATH=$(dirname $0)
pushd $(pwd)
cd $SCRIPT_PATH



echo "Installing HA software (Pacemaker, Corosync, haproxy, jq) on the load balancer nodes:"
for node in $(grep -v \# /etc/hosts| grep "lb[0-9]\."  | awk '{print $2}'); do

  echo "Processing node: ${node}"
  scp /etc/hosts root@${node}:/etc/hosts

  ssh root@${node}  "yum -q -y install jq haproxy pacemaker pcs corosync psmisc nginx git"

  # Firewalld is such a pain in the neck, that I decided to forcibly remove it and stop the iptables, 
  #   to make sure that it does not interfere withe the cluster. This is VERY important.
  ssh root@${node} "systemctl stop iptables firewalld ; yum -q -y remove firewalld; iptables -t nat -F ; iptables -F"

  echo
  echo "Enabling and staring PCSD service on node $node ..."
  echo
  ssh root@${node} "systemctl enable pcsd.service; systemctl stop pcsd.service; systemctl start pcsd.service"

done

# Let the cluster settle down and decide who will be the leader, etc.
sleep 2



echo "========================================================================================="

echo "Configure HA software on LB nodes ..."

for node in $(grep -v \# /etc/hosts| grep "lb[0-9]\."  | awk '{print $2}'); do
  echo "Setting up HA on node: ${node}"
  scp configure-loadbalancer-HA.sh root@${node}:/root/
  ssh root@${node} "/root/configure-loadbalancer-HA.sh"
  echo "---------------------------------------------------"
done

# Done
popd



