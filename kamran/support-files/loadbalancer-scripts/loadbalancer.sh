#!/bin/bash
# Author: Kamran Azeem (kaz@praqma.net)
# Summary: This script sets up a load balancer using the information from a working kubernetes cluster. 
# In case of conflict, the script adjusts load balancer, and not the kubernetes cluster.

# Load the configuration variables from the conf file. The conf file is expected in /opt.
if [ -r /opt/loadbalancer.conf ]; then 
  source /opt/loadbalancer.conf
else
  # If conf file is not in /opt, use a local copy from current directory.
  source ./loadbalancer.conf
fi



###### START - FUNCTIONS ##################

function Check_LB_IP() {
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
    echo "The IP you provided as LB_PRIMARY_IP (${LB_PRIMARY_IP}) in the conf file, is not found on this load balancer system. Please check."
    exit 1
  fi

  LB_SUBNET_BITS=$FOUND_SUBNET_BITS
  LB_PRIMARY_IP_INTERFACE=$FOUND_INTERFACE

}


#---------------------------------------------

function Check_Database() {
  # Check if the Load Balancer's SQLite DB exists.
  echo
  if [ -r $LB_DATABASE ]; then
    # Make sure that the file is a valid SQLite file type
    FILE_TYPE=$(file --brief $LB_DATABASE)
    if [ "$FILE_TYPE" == "SQLite 3.x database" ]; then
      echo "Load Balancer SQLite database exists as:"
      file $LB_DATABASE
      return
    else
      echo "The file $LB_DATABASE is not a valid SQLite version 3 format."
      exit 9
    fi
  else
    echo "Load Balancer SQLite database $LB_DATABASE does not exist or is not readable. Please check."
    exit 9
  fi
}


#---------------------------------------------

function Check_Master_SSH_Connectivity() {
  # echo "Check if kubernetes master $MASTER_IP is reachable over SSH ..."
  REMOTESERVER=$MASTER_IP
  REMOTESSHPORT=22
  echo
  echo -n "Checking if kubernetes master $MASTER_IP is reachable over SSH ..."

  2>/dev/null >/dev/tcp/${REMOTESERVER}/${REMOTESSHPORT}
  if [ $? -gt 0 ]; then
    echo "No :( Kubernetes master: ${REMOTESERVER} was not reachable on SSH (port ${REMOTESSHPORT})"
    exit 2
  else
    echo "Yes! :) Success connecting to Kubernetes master ${REMOTESERVER} on port ${REMOTESSHPORT} !"
  fi
}

#---------------------------------------------


function Check_Master_SSH_Command_Execution() {
  echo
  # echo "Check if the user $MASTER_USER is able to run commands on kubernetes master $MASTER_IP."
  # echo "(You may need to accept the fingerprint of the master when this script is run for the first time.)"
  echo "Running command '$1' as user $MASTER_USER on Kubernetes Master $MASTER_IP."
  echo
  ssh ${MASTER_USER}@${MASTER_IP} "$1"

  if [ $? -gt 0 ]; then
    echo "There was a problem running '$1' through ${MASTER_USER}@${MASTER_IP} over SSH. Please check."
    exit 9
  fi
}


#---------------------------------------------

function Show_LB_Status() {
  # Lets display records from the LB database:
  echo 
  echo "Displaying data from the table 'ServiceToEndPointsMapping' , from the database 'LoadBalancer' :"
  echo "-----------------------------------------------------------------------------------------------"
  sqlite3 $LB_DATABASE "select * from ServiceToEndPointsMapping;"
  echo "-----------------------------------------------------------------------------------------------"
  echo 
}



#
###### END - FUNCTIONS ####################


###### START - SANITY CHECKS ##############
#
echo
echo "Starting Sanity checks ..."

Check_LB_IP

Check_Database

Check_Master_SSH_Connectivity
Check_Master_SSH_Command_Execution "uptime"

# cs is abbreviation of componentstatuses! 
Check_Master_SSH_Command_Execution "kubectl get cs"

Check_FLANNEL


# Showing status is not actually a sanity check ...
Show_LB_Status
echo
echo "Sanity checks completed successfully!"
#
###### END - SANITY CHECKS #################






#### START - PROGRAM CODE #################
echo
echo "Beginning execution of main program ..."
case $1 in 
add)
  Message="Add a mapping."
  ;;
delete)
  Message="Delete a mapping."
  ;;
update)
  Message="Update a mapping."
  ;;
show)
  Message="Show a mapping."
  Show_LB_Status
  ;;
*)
  Message="You need to use one of the operations: add|delete|update|show"
  ;;
esac

echo $Message


#
##### END - PROGRAM CODE ###################
