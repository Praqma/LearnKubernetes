#!/bin/bash
# Load the configuration variables from the conf file. The conf file is expected in /opt.
if [ -r /opt/loadbalancer.conf ]; then 
  source /opt/loadbalancer.conf
else
  source loadbalancer.conf
fi

# Check if the variables are not null. 
if [ -z $LB_PRIMARY_IP ]; then
  echo "LB_PRIMARY_IP cannot be empty. This needs to be IP of an interface on LB, which is never to be shutdown."
  exit 1
fi


# See if the LB_PRIMARY_IP is found on one of the interfaces of the local system, and which interface is it? :
FOUND_IP=$(ip addr | grep -w $LB_PRIMARY_IP | sed 's/.*inet \(.*\)\/.*$/\1/')
FOUND_SUBNET_BITS=$(ip addr | grep -w $LB_PRIMARY_IP | sed 's/.*\/\(.*\) brd .*$/\1/')
FOUND_INTERFACE=$(ip addr | grep -w $LB_PRIMARY_IP | sed 's/.* global \(.*\)$/\1/')

if [ "$LB_PRIMARY_IP" != "$FOUND_IP" ]; then
  echo
  echo "The IP you provided as LB_PRIMARY_IP in the conf file, is not found on the LB system. Please check."
  exit 1
fi

LB_SUBNET_BITS=$FOUND_SUBNET_BITS
LB_PRIMARY_IP_INTERFACE=$FOUND_INTERFACE

echo "Check if kubernetes master is reachable over SSH ..."
  REMOTESERVER=$MASTER_IP
  REMOTESSHPORT=22
  echo
  echo "Checking SSH connectivity to $REMOTESERVER ."

  2>/dev/null >/dev/tcp/${REMOTESERVER}/${REMOTESSHPORT}
  if [ $? -gt 0 ]; then
    echo "Remote server: ${REMOTESERVER} was not reachable on SSH (port ${REMOTESSHPORT})."
    exit 2
  else
    echo "Success connecting to ${REMOTESERVER} on port ${REMOTESSHPORT}"
  fi

echo 
echo "Check if the user $MASTER_USER is able to run commands on the master."
echo "You may need to accept the fingerprint of the master when this script is run for the first time."
ssh ${MASTER_USER}@${MASTER_IP} uptime

if [ $? -gt 0 ]; then
  echo "There was a problem running a command through ${MASTER_USER}@${MASTER_IP} over SSH. Please check."
  exit 9
fi

# Check if the Load Balancer's SQLite DB exists.
echo
if [ -r $LB_DATABASE ]; then
  echo "Load Balancer SQLite database exists as $LB_DATABASE"
  file $LB_DATABASE
else
  echo "Load Balancer SQLite database $LB_DATABASE does not exist or is not readable. Please check."
  exit 9
fi

# Lets display records from the LB database:
echo 
echo "Displaying data from the ServiceToEndPointsMapping table from LoadBalancer database ..."
echo "---------------------------------------------------------------------------------------"
sqlite3 $LB_DATABASE "select * from ServiceToEndPointsMapping;"
echo "---------------------------------------------------------------------------------------"

# Alright, lets see if we can do simple kubectl operation:
echo
ssh ${MASTER_USER}@${MASTER_IP} kubectl get services

