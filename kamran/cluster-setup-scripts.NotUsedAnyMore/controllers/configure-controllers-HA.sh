#!/bin/bash 
# Configure-HA-controllers.sh

# Set the password you want for the hacluster user. This will only be used by pcsd service to sync cluster.
PASSWORD="redhat"
VIP="10.240.0.20"

# Need to have packages installed and pcs service running on all nodes, before you move forward , or before you use this script.

echo 
echo "------------------- Setting up HA on controller node ..."
echo 
# Setting password for user hacluster ...
echo "hacluster:${PASSWORD}" | chpasswd


echo "Authenticate user hacluster to the cluster nodes ..."
pcs cluster auth -u hacluster -p ${PASSWORD} controller1.example.com  controller2.example.com 


echo "Checking PCS cluster status on node ..."
pcs status pcsd

# Execute the following code on node1 only

if [ "$(hostname -s)" == "controller1" ]; then

  echo "Executing pcs cluster setup commands on node1 only ..."
  sleep 5

  echo "Creating CoroSync communication cluster/service ..."
  pcs cluster setup --name ControllerHA controller1.example.com controller2.example.com --force 

  echo "Starting cluster on all cluster nodes ... This may take few seconds ..."
  pcs cluster start --all
  sleep 10

  # this enables the corosync and pacemaker services to start at boot time.
  pcs cluster enable --all
  sleep 1

  pcs property set stonith-enabled=false
  sleep 5

  pcs status nodes
  sleep 1

  pcs status resources
  sleep 1

  pcs status corosync
  
  echo "Setting up cluster resource VIP as ${VIP} ..."
  pcs resource create ControllerVIP ocf:heartbeat:IPaddr2 ip=${VIP} cidr_netmask=32 op monitor interval=30s

  # Allow cluster some time to decide where would it run the VIP resource
  sleep 5

fi

echo "Following code can run on all nodes ..."
echo "Check corosync ring status ..."
corosync-cfgtool -s


echo "Show status of corosync and pacemaker on all nodes ..."
systemctl status corosync pacemaker


echo "Showing final pcs status ..."
pcs status

echo "Showing ip address ..."
ip addr


##############################################
# Re-use this script for Load balancer
# Configure HAProxy , (have a synced config haproxy),  grouping of VIP with HAProxy, order VIP first, HAProxy second .



