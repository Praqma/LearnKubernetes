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
  echo "Displaying data from the table 'ServiceToEndPointsMapping' , from the 'main' database:"
  echo "--------------------------------------------------------------------------------------"
  sqlite3 $LB_DATABASE "select * from ServiceToEndPointsMapping;"
  echo "--------------------------------------------------------------------------------------"
  echo 
}


#---------------------------------------------

function Services_Info_Table() {
  OPERATION=$1
  # This function builds the information table in the SQL DB. 

  # Reset IFS to null. Sometimes IFS can be a pain in the ***
  IFS=''

  # SERVICE_LIST=$(ssh ${MASTER_USER}@${MASTER_IP} "kubectl get services --all-namespaces=true | egrep -v '<none>|AGE'" | tr '\n' '\n\r')
  SERVICE_LIST=$(ssh -n ${MASTER_USER}@${MASTER_IP} "kubectl get services --all-namespaces=true | egrep -v '<none>|AGE'" )
  # Be careful: SSH reads from standard input and eats all remaining lines. Use ssh -n
  # Tip: from http://stackoverflow.com/questions/9393038/ssh-breaks-out-of-while-loop-in-bash

  # There seems to be a problem in the way the kubectl output is formatted. Something wrong with line endings.
  # (Actually it turned out to be a problem caused by SSH. but ayway). 

  # Tip from: http://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable
  echo "Following services were found with external IPs - on Kubernetes master ..."
  echo "-----------------------------------------------------------------------------------------------"

  # Sometimes for does not work as expected with output of other programs, such as sqlite.
  # use while intead  # for LINE in  $SERVICE_LIST; do
  echo $SERVICE_LIST | while IFS='' read -r SERVICE_LINE || [[ -n "$SERVICE_LINE" ]]; do
    echo $SERVICE_LINE
    if [ "$OPERATION" == "insert" ]; then
      # echo "******** Inserting record: $SERVICE_LINE"
      INSERT_SERVICE_RECORD_IN_DB $SERVICE_LINE
    fi
  done
}

#---------------------------------------------

function FIND_SERVICE_ENDPOINTS() {
  # ORIG_IFS=$IFS
  # This function describes a service and extracts endpoints information, which is then inserted into the main DB table.
  # Receives two variables as parameters - namespace and service.
  NAMESPACE=$1
  SERVICE=$2

  # Tip from: http://stackoverflow.com/questions/9393038/ssh-breaks-out-of-while-loop-in-bash
  MYENDPOINTS=$(ssh -n ${MASTER_USER}@${MASTER_IP} "kubectl --namespace=${NAMESPACE} describe service ${SERVICE}  | grep 'Endpoints:'" | awk '{print $2}')
  echo "${MYENDPOINTS}"
  # IFS=$ORIG_IFS
}


#---------------------------------------------

function INSERT_SERVICE_RECORD_IN_DB() {
  # This function expects a record input as $1. It breaks it down into fields and then adds that to the datbase.
  SERVICE_RECORD=$1
  # Set Input Field Separator to a space.
  ORIG_IFS=$IFS
  IFS=' '
  # break a record fields into separate variables.
  set $SERVICE_RECORD
  # We know that format of a record is:
  # NAMESPACE  SERVICENAME  CLUSTER-IP  EXTERNAL-IP  PORT(S)  AGE
  # $1         $2           $3          $4           $5       $6
  NAMESPACE_NAME=$1
  SERVICE_NAME=$2
  CLUSTER_IP=$3
  EXTERNAL_IP=$4
  PORTS=$5
  FOUND_END_POINTS=""

  # Just before we insert these values in the db table, we need to find the Endpoints, so we can add complete information in one go.
  # FIND_SERVICE_ENDPOINTS $NAMESPACE_NAME $SERVICE_NAME 
  FOUND_END_POINTS=$(FIND_SERVICE_ENDPOINTS $NAMESPACE_NAME $SERVICE_NAME)
  # echo "FOUND the END POINTS as: $FOUND_END_POINTS"

  # Insert these values (including Endpoints information) in the database table (skipping AGE):
  echo -n "Inserting in database, with endpoints: $FOUND_END_POINTS "
  sqlite3 $LB_DATABASE \
	"insert into ServiceToEndPointsMapping values(\"$NAMESPACE_NAME\",\"$SERVICE_NAME\",\"$CLUSTER_IP\",\"$EXTERNAL_IP\",\"$PORTS\",\"$FOUND_END_POINTS\");"
  if [ $? -eq 0 ]; then
    echo "... INSERTED!"
  else
    echo "... INSERT failed!"
  fi 
  # Reset IFS, otherwise it messes up with the parent function if it is being used there.
  IFS=$ORIG_IFS
}


#---------------------------------------------

function CREATE_HA_PROXY_CONFIG() {

  TEMP_HAPROXY_CONF="/tmp/haproxy-loadbalancer.cfg"

  if [ -r $TEMP_HAPROXY_CONF ] ; then
    rm -f $TEMP_HAPROXY_CONF
    touch $TEMP_HAPROXY_CONF
  fi 

  # Here we create a config file , which will later on be matched with the running config file (in another function). 
  cp haproxy-global-default.cfg $TEMP_HAPROXY_CONF
  
  # We need to translate the | signs from the sql output into space, so later we can break the record into individual values. 

  # This commented line works independently of setting IFS again in the loop 
  # sqlite3 $LB_DATABASE "select * from ServiceToEndPointsMapping ;" | tr '|' ' ' | while IFS='' read -r SERVICE_LINE || [[ -n "$SERVICE_LINE" ]]; do

  # The sqlite command below needs a secondary IFS=\| in the main loop.
  sqlite3 $LB_DATABASE "select * from ServiceToEndPointsMapping ;" | while IFS='' read -r SERVICE_LINE || [[ -n "$SERVICE_LINE" ]]; do
    ORIG_IFS=$IFS
    IFS=\|
    echo $SERVICE_LINE
    set $SERVICE_LINE
    echo "$1, $2, $3, $4, $5, $6" 
    NAMESPACE=$1
    SERVICE=$2
    CLUSTERIP=$3
    EXTERNALIP=$4
    PORTS=$5
    ENDPOINTS=$6
    # There can be multiple ports for one external IP such as a web server running both 80 and 443. Need to find a way to manage that.
    # For now I will work with only one port.
    PORT=$(echo $PORTS| cut -d '/' -f 1)
    echo "-------------------------------------------------"
    echo "" >> $TEMP_HAPROXY_CONF
    echo "listen ${NAMESPACE}-${SERVICE}-${PORT}" >> $TEMP_HAPROXY_CONF
    # Is there a way to pass a tab in echo?
    echo "      bind ${EXTERNALIP}:${PORT}" >> $TEMP_HAPROXY_CONF
    # Need to break the endpoints line into individual lines, using a function
    WRITE_ENDPOINTS_IN_CONFIG $ENDPOINTS
    echo "--------------------------------------------------"
    IFS=$ORIG_IFS
  done

}


# ------------------------------------

function WRITE_ENDPOINTS_IN_CONFIG() {
  ENDPOINTS=$1
  ORIG_IFS=$IFS
  IFS=','
  COUNTER=1
  for ENDPOINT in ${ENDPOINTS[@]}; do
    echo "        server pod-${COUNTER} $ENDPOINT check" >> $TEMP_HAPROXY_CONF
    let COUNTER++
  done
  IFS=$ORIG_IFS
}


#
###### END - FUNCTIONS ####################


###### START - SANITY CHECKS ##############
#
echo
echo "Starting Sanity checks ..."

Check_LB_IP

Check_FLANNEL

Check_Database

Check_Master_SSH_Connectivity
Check_Master_SSH_Command_Execution "uptime"

# cs is abbreviation of componentstatuses! 
Check_Master_SSH_Command_Execution "kubectl get cs"

# Showing status is not actually a sanity check ...
# Show_LB_Status

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
  Services_Info_Table insert
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
  Services_Info_Table show
  ;;
create-config)
  CREATE_HA_PROXY_CONFIG
  ;;
*)
  Message="You need to use one of the operations: add|delete|update|show"
  ;;
esac

echo $Message

echo

echo "TODO:"
echo "-----"
echo "* Use [root@loadbalancer ~]# curl -k -s -u vagrant:vagrant  https://10.245.1.2/api/v1/namespaces/default/endpoints/apache | grep ip"
echo "The above is better to use instead of getting endpoints from kubectl, because kubectl only shows 2-3 endpoints and says +XX more..."
echo "* Create multiple listen sections depending on the ports of a service. such as 80, 443 for web servers. This may be tricky. Or there can be two bind commands in one listen directive/section."
echo "* Add test for flannel interface to be up"
echo "* Add check for the LB primary IP. If it is found in kubernetes service definitions on master, abort program and as user to fix that first. LB Primary IP must not be used as a external IP in any of the services."
echo "* Use local kubectl instead of SSHing into Master"
echo
#
##### END - PROGRAM CODE ###################
