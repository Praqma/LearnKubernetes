#!/bin/bash 
# Configure HA on LB nodes

# Set the password you want for the hacluster user. This will only be used by pcsd service to sync cluster.
PASSWORD="redhat"

VIP=$(cat /etc/hosts | grep "lb\." | awk '{print $1}')

HOSTNAME=$(hostname -s)


# Need to have packages installed and pcs service running on all nodes, before you move forward , or before you use this script.

# echo "-------------------- Setting up HA software (PCS)  on node: $HOSTNAME"

# This is already done in the parent script
# echo "(pre)Installing HA software: pacemaker corosync pcs psmisc nginx ..."
# yum -q -y install pacemaker corosync pcs psmisc nginx jq


# Install / download the OCF compliant heartbeat resource agent for haproxy.
curl -s -O https://raw.githubusercontent.com/thisismitch/cluster-agents/master/haproxy
chmod +x haproxy
cp haproxy  /usr/lib/ocf/resource.d/heartbeat/ 
# (Yes, it should be saved in /usr/lib/ocf/resource.d/heartbeat  , and NOT in /usr/lib/ocf/resource.d/pacemaker)

# This is already done in parent script.
# echo "(pre) Enabling HA service: PCSD ..."
# systemctl enable pcsd.service
# systemctl stop pcsd.service
# systemctl start pcsd.service

echo
echo "===================================================================================================="
echo

echo 
echo "------------------- Setting up HA on Load Balancer node $HOSTNAME..."
echo 
# Setting password for user hacluster ...
echo "hacluster:${PASSWORD}" | chpasswd


echo "Authenticate user 'hacluster' to the cluster nodes ..."
pcs cluster auth -u hacluster -p ${PASSWORD} lb1.example.com  lb2.example.com 


echo "Checking PCS cluster status on node ..."
pcs status pcsd

# Execute the following code on node1 only

if [ "$(hostname -s)" == "lb1" ]; then

  echo "Executing pcs cluster setup commands on node1 only ..."


  echo "Creating CoroSync communication cluster/service ..."
  pcs cluster setup --name LoadbalancerHA lb1.example.com lb2.example.com --force 
  sleep 5

  echo "Starting cluster on all cluster nodes ... This may take few seconds ..."
  pcs cluster start --all
  sleep 5

  # this enables the corosync and pacemaker services to start at boot time.
  pcs cluster enable --all
  sleep 1

  # We do not have stonith device, (nor we are likely to get one), so disable stonith 
  pcs property set stonith-enabled=false
  sleep 5

  pcs status nodes
  sleep 1

  pcs status resources
  sleep 1

  pcs status corosync
  
  echo "Setting up cluster resource LoadbalancerVIP as ${VIP} ..."
  pcs resource create LoadbalancerVIP ocf:heartbeat:IPaddr2 ip=${VIP} cidr_netmask=32 op monitor interval=30s

  # Allow cluster some time to decide where would it run the VIP resource
  sleep 5

  echo "Setting up cluster resource HAProxy ..."
  pcs resource create HAProxy ocf:heartbeat:haproxy conffile=/etc/haproxy/haproxy.cfg op monitor interval=1min
  sleep 5

  # Make sure that LoadbalancerVIP and HAProxy are on same node, and haproxy starts after LoadbalancerVIP.
  pcs constraint colocation add HAProxy LoadbalancerVIP INFINITY
  pcs constraint order LoadbalancerVIP then HAProxy
  sleep 5
fi

echo "Following code will run on all nodes ..."
echo "Check corosync ring status on node $HOSTNAME..."
corosync-cfgtool -s


echo "Show status of corosync and pacemaker on node $HOSTNAME ..."
systemctl status corosync pacemaker


echo "Showing final pcs status on node $HOSTNAME..."
pcs status

echo "Showing ip address on $HOSTNAME..."
ip addr


##############################################

echo
echo "================================================================="
echo

echo "Setting up Praqma Load Balancer ..."
git clone -q  https://github.com/Praqma/k8s-cloud-loadbalancer.git

