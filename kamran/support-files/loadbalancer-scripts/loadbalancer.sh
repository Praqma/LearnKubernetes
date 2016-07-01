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
  echo "Displaying data from the table 'Services' , from the 'main' database:"
  echo "--------------------------------------------------------------------------------------"
  sqlite3 $LB_DATABASE "select * from Services;"
  echo "--------------------------------------------------------------------------------------"
  echo 
}


#---------------------------------------------

function Services_Info_Table() {
  OPERATION=$1

  ########################################################################################################
  #
  # Why not start creating the haproxy conf file straight away?!
  #
  TEMP_HAPROXY_CONF="/tmp/haproxy-loadbalancer.cfg"

  if [ -r $TEMP_HAPROXY_CONF ] ; then
    rm -f $TEMP_HAPROXY_CONF
    touch $TEMP_HAPROXY_CONF
  fi

  # Here we create a config file , which will later on be matched with the running config file (in another function).
  cp haproxy-global-default.cfg $TEMP_HAPROXY_CONF

  #  
  #
  ########################################################################################################

  # SERVICE_LIST=$(ssh ${MASTER_USER}@${MASTER_IP} "kubectl get services --all-namespaces=true | egrep -v '<none>|AGE'" | tr '\n' '\n\r')
  SERVICE_LIST=$(ssh -n ${MASTER_USER}@${MASTER_IP} "kubectl get services --all-namespaces=true | egrep -v '<none>|AGE'" )

  # Be careful: SSH reads from standard input and eats all remaining lines. Use ssh -n
  # Tip: from http://stackoverflow.com/questions/9393038/ssh-breaks-out-of-while-loop-in-bash

  # There seems to be a problem in the way the kubectl output is formatted. Something wrong with line endings.
  # (Actually it turned out to be a problem caused by SSH. but ayway). 

  # Tip from: http://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable
  echo "Following services were found with external IPs - on Kubernetes master ..."


  ORIG_IFS=$IFS

  # Set IFS to null. This is needed for the loop below to work and separate services into separate lines/records.
  IFS=''

  # Sometimes for does not work as expected with output of other programs, such as sqlite.
  # use while intead  # for LINE in  $SERVICE_LIST; do

  echo $SERVICE_LIST | while IFS='' read -r SERVICE_LINE || [[ -n "$SERVICE_LINE" ]]; do

    # Not possible to have  summarzed IP info from kubectl for this service, 
    # because we do not have a namespace and service name yet. We just have one long line.

    echo "===================================================================================================="
    echo "${SERVICE_LINE}"
    # echo "--------------------------------------------------------------------------------------------------"
    if [ "$OPERATION" == "create" ]; then
      # echo "******** Displaying record: $SERVICE_LINE"
      CREATE_SERVICE_SECTION_IN_HAPROXY $SERVICE_LINE
    fi
  done

  IFS=$ORIG_IFS
}


#---------------------------------------------

function CREATE_SERVICE_SECTION_IN_HAPROXY() {
  # This function expects a single record as input - as $1. It breaks it down into fields and then adds that to the database.
  SERVICE_RECORD=$1
  # Set Input Field Separator to a space because output of "kubectl get services" (each line) is separated by space.
  ORIG_IFS=$IFS

  # Set IFS to space beause the incomging service record is the output from kubectl and has spaces as field delimiter.
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

  # Reset IFS immediately after the record breakup into separate variables is done.
  IFS=$ORIG_IFS

  # Debug - Works beautifully till this point. Services go into Services table as separate records.Good.
  


  #############################################################################################
  #
  # Instead of inserting into SQL DB, we can just create the conf file, straight away.
  # code here.
  # There can be multiple ports for one external IP such as a web server running both 80 and 443. Need to find a way to manage that.
  # For now I will work with only one port.
  # Ideally a separate service should be created to cater for each type of traffic/port type.

  
  PORT=$(echo $PORTS| cut -d '/' -f 1 | tr -d ' ')
  echo "-----> Creating HA proxy section: ${NAMESPACE_NAME}-${SERVICE_NAME}-${PORT}"
  echo "" >> $TEMP_HAPROXY_CONF
  # In the following code, one line is for screen, and the other is for the haproxy conf file
  echo "listen ${NAMESPACE_NAME}-${SERVICE_NAME}-${PORT}"
  echo "listen ${NAMESPACE_NAME}-${SERVICE_NAME}-${PORT}" >> $TEMP_HAPROXY_CONF
  echo "        bind ${EXTERNAL_IP}:${PORT}"
  echo "        bind ${EXTERNAL_IP}:${PORT}" >> $TEMP_HAPROXY_CONF

  #  
  #
  #############################################################################################

  # Now add Endpoints to this service, which are obtained separately by using the call to apiserver's http interface.
  POPULATE_SERVICE_ENDPOINTS $NAMESPACE_NAME $SERVICE_NAME 
}

#---------------------------------------------

function POPULATE_SERVICE_ENDPOINTS() {
  ORIG_IFS=$IFS
  # This function describes a service and extracts endpoints information, which is then inserted into the main DB table.
  # Receives two variables as parameters - namespace and service.
  NAMESPACE=$1
  SERVICE=$2
  ENDPOINTS_IPS=$(ssh -n ${MASTER_USER}@${MASTER_IP} "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICE}" | egrep -w 'ip' | sed  -e 's/\"//g'  -e 's/ip://g' -e 's/,//g' | tr -d ' ' | tr '\n' ' ' )

  ENDPOINTS_PORT=$(ssh -n ${MASTER_USER}@${MASTER_IP} "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICE}" | egrep -w 'port' | sed  -e 's/\"//g' -e 's/,//'  | cut -f 2  -d ':'  | tr -d ' '  )

  # echo "Inserting Endpoints information in haproxy conf file ..."
  # echo "ENDPOINTS_IPS are: oooo${ENDPOINTS_IPS}OOOO"
  # echo "--------------------------------"
  # echo "ENDPOINTS_PORT is: oooo${ENDPOINTS_PORT}OOOO"

  IFS=' '
  COUNTER=1

  for i in ${ENDPOINTS_IPS[@]}; do 
    echo "        server pod-${COUNTER} ${i}:${ENDPOINTS_PORT} check"
    echo "        server pod-${COUNTER} ${i}:${ENDPOINTS_PORT} check" >> $TEMP_HAPROXY_CONF
    let COUNTER++
  done

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
  # sqlite3 $LB_DATABASE "select * from Services ;" | tr '|' ' ' | while IFS='' read -r SERVICE_LINE || [[ -n "$SERVICE_LINE" ]]; do

  # The sqlite command below needs a secondary IFS=\| in the main loop.
  sqlite3 $LB_DATABASE "select * from Services ;" | while IFS='' read -r SERVICE_LINE || [[ -n "$SERVICE_LINE" ]]; do
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
    # There can be multiple ports for one external IP such as a web server running both 80 and 443. Need to find a way to manage that.
    # For now I will work with only one port.
    # Ideally a separate service should be created to cater for each type of traffic/port type. 
    PORT=$(echo $PORTS| cut -d '/' -f 1)
    echo "-------------------------------------------------"
    echo "" >> $TEMP_HAPROXY_CONF
    echo "listen ${NAMESPACE}-${SERVICE}-${PORT}" >> $TEMP_HAPROXY_CONF
    # Is there a way to pass a tab in echo?
    echo "      bind ${EXTERNALIP}:${PORT}" >> $TEMP_HAPROXY_CONF
    # Endpoints are obtained separately by using the call to apiserver's http interface. 
    # It is because the endpoints shown in the kubectl describe service command are limited and more than three endpoints
    # are hidden/replaced by "+3 more", etc, which is VERY stupid. 

    # The function below will talk to api server over ssh , gather neessary information about endpoints, and write a config file.
    # I need to pass NameSpace and Service names to this function
    WRITE_ENDPOINTS_IN_CONFIG $NAMESPACE, $SERVICE
    echo "--------------------------------------------------"
    IFS=$ORIG_IFS
  done

}


# ------------------------------------

function WRITE_ENDPOINTS_IN_CONFIG() {
  NAMESPACE=$1
  SERVICENAME=$2


  # SSH to apiserver, get endpoints from api's http interface and parse the options:
  # ENDPOINTS_IPS=$(ssh -n ${MASTER_USER}@${MASTER_IP} "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICENAME}" | egrep -w 'ip' | sed  -e 's/\"//g'  -e 's/ip://g' -e 's/,//g' ) 
  # ENDPOINTS_PORT=$(ssh ${MASTER_USER}@${MASTER_IP "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICENAME}" | egrep -w 'port' | sed  -e 's/\"//g' -e 's/,//'  | cut -f 2  -d ':' )

  # Use the database table to extract endpoints information and write configs
  sqlite3 $LB_DATABASE "select * from ServiceEndPoints where NameSpace=\'$NAMESPACE\' and ServiceName=\'$SERVICENAME\' ;" | while IFS='' read -r ENDPOINT_LINE || [[ -n "$ENDPOINT_LINE" ]]; do
    #ORIG_IFS=$IFS
    #IFS=\|
    echo "Display w/o Insert: $ENDPOINT_LINE"
    # set $ENDPOINT_LINE
    echo " --------------------------------------"
  done



  # original code:
  # ORIG_IFS=$IFS
  # IFS=','
  # COUNTER=1
  # for ENDPOINT in ${ENDPOINTS_IPS[@]}; do
  #   echo "        server pod-${COUNTER} ${ENDPOINT}:${ENDPOINTS_PORT} check" >> $TEMP_HAPROXY_CONF
  #   let COUNTER++
  # done
  # IFS=$ORIG_IFS
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
create)
  Message="Create new haproxy configuration."
  Services_Info_Table create
  ;;
delete)
  Message="Delete a mapping."
  ;;
update)
  Message="Update a mapping."
  ;;
show)
  Message="Show a mapping."
  # The LB DB is only for it's internal working. There is no need to show a DB, which may have no records, 
  # or records, which are now not in sync with current cluster/services state.
  # Show_LB_Status
  Services_Info_Table show
  ;;
create-config)
  CREATE_HA_PROXY_CONFIG
  ;;
*)
  Message="You need to use one of the operations: create|delete|update|show"
  ;;
esac

echo ""
echo "oooooooooooooooooooo $Message - Operation completed. oooooooooooooooooooo" 

echo

echo "TODO:"
echo "-----"
echo "* - Compare temporary haproxy conf with the one which is running. If different replace the conf file and reload service. "
echo "* - Add IP management on the LB PRIMARY interface."
echo "* - Use [root@loadbalancer ~]# curl -k -s -u vagrant:vagrant  https://10.245.1.2/api/v1/namespaces/default/endpoints/apache | grep ip"
echo "    The above is better to use instead of getting endpoints from kubectl, because kubectl only shows 2-3 endpoints and says +XX more..."
echo "* - Create multiple listen sections depending on the ports of a service. such as 80, 443 for web servers. This may be tricky. Or there can be two bind commands in one listen directive/section."
echo "* - Add test for flannel interface to be up"
echo "* - Add check for the LB primary IP. If it is found in kubernetes service definitions on master, abort program and as user to fix that first. LB Primary IP must not be used as a external IP in any of the services."
echo "* - Use local kubectl instead of SSHing into Master"
echo
#
##### END - PROGRAM CODE ###################
