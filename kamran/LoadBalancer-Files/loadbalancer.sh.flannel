#!/bin/bash
# Author: Kamran Azeem (kaz@praqma.net)
# Summary: This script sets up a load balancer using the information from a working kubernetes cluster. 
# In case of conflict, the script adjusts load balancer, and not the kubernetes cluster.
# The program lock file can be removed manually if it doesn't get deleted because of some weird reason.

# Load the configuration variables from the conf file. The conf file is expected in /opt.
if [ -r /opt/loadbalancer.conf ]; then 
  source /opt/loadbalancer.conf
else
  # If conf file is not in /opt, use a local copy from current directory.
  source ./loadbalancer.conf
fi

# Note: echolog is a function, which echo's a string and also logs it in the LB_LOG_FILE

###### START - INTERNAL VARIABLES ########

LOCK_FILE=/var/lock/loadbalancer



###### END - INTERNAL VARIABLES ##########


###### START - FUNCTIONS ##################

function CHECK_FLANNEL() {
  # This function checks if flannel service is running. If not, it exists complaining so.

  echo
  echo "Checking Flannel service (flanneld) ..."
  # The pidof mechanism is not very helpful. It is quite possible that flannel service might be trying to start,
  #   but failing for some reason, as it may not be able to connect to the etcd service for whatever reason.
  #   At that instance, if this script runs and pidof test is run, it just sees a process with a name flanneld running,
  #   it does not know if it has started successfully, or still trying. 
  #   For this reason, pidof is not such a nice test. I would use service status with error code higher than 0 as error.

  ## FLANNEL_PID=$(pidof flanneld) 
  systemctl status flanneld > /dev/null
  FLANNEL_ERROR_CODE=$?


  if [ ${FLANNEL_ERROR_CODE} -gt 0 ]; then
    echolog "Something is wrong with flannel service. It needs to be running before the loadbalancer could work. Please check."
    echo
    exit 9
  else
    # If reached here, it means flannel is running. What IP does it have? Just for information to the sysadmin.
    # Remember it is a /16 IP ADDRESS, not a NETWORK ADDRESS.
    FLANNEL_IP=$(ip addr show dev flannel0 | grep -w inet | awk '{print $2}')
    if [ -z "$FLANNEL_IP" ]; then
      echolog "Apparently Flannel service is running but we could not obtain IP address of flannel0 interface. Please check."
      exit 9
    else
      echolog "Flannel service (flanneld) seems to be running with the IP address of ${FLANNEL_IP}"
    fi
    echo
  fi



}

#---------------------------------------------

function Check_LB_IP() {
  if [ -z "$LB_PRIMARY_IP" ]; then
    echolog "LB_PRIMARY_IP cannot be empty. This needs to be IP of an interface on LB, which is never to be shutdown."
    exit 1
  fi

  # See if the LB_PRIMARY_IP is found on one of the interfaces of the local system, and which interface is it? :
  FOUND_IP=$(ip addr | egrep -w -v 'secondary|forever|inet6|link' | grep -w $LB_PRIMARY_IP | sed 's/.*inet \(.*\)\/.*$/\1/')
  FOUND_SUBNET_BITS=$(ip addr | egrep -w -v 'secondary|forever|inet6|link' | grep -w $LB_PRIMARY_IP | sed 's/.*\/\(.*\) brd .*$/\1/')
  FOUND_INTERFACE=$(ip addr | egrep -w -v 'secondary|forever|inet6|link' | grep -w $LB_PRIMARY_IP | sed 's/.* global \(.*\)$/\1/')

  if [ "$LB_PRIMARY_IP" != "$FOUND_IP" ]; then
    echo
    echolog "The IP you provided as LB_PRIMARY_IP (${LB_PRIMARY_IP}) in the conf file, is not found on this load balancer system. Please check."
    exit 1
  fi

  LB_SUBNET_BITS=$FOUND_SUBNET_BITS
  LB_PRIMARY_IP_INTERFACE=$FOUND_INTERFACE

}


#---------------------------------------------

function CHECK_KUBE_SERVICE_FOR_LB_IP() {
  # If Any of the Kubernetes service is using our load balancer's primary IP, then fail the script.
  # We do not want anyone to use our primary LB IP in kubernetes services.


  SERVICE_WITH_PRIMARY_LB_IP=$(ssh -o ConnectTimeout=5 -n ${MASTER_USER}@${MASTER_IP} "kubectl get services --all-namespaces=true | egrep -v '<none>|AGE' | grep $LB_PRIMARY_IP" )
  # THe double quotes in the test are important.
  if [ ! -z "${SERVICE_WITH_PRIMARY_LB_IP}" ]; then
    echo
    echolog "Some service in Kubernetes has it's External-IP set as the primary IP address of the load-balancer (${LB_PRIMARY_IP}) ."
    echolog "This is not permitted. You should find an available IP address from the available pool of IPs and assign those IPs to your services when exposing them."
    echo
    echolog "Here is the problematic service from kubernetes master:"
    echolog "${SERVICE_WITH_PRIMARY_LB_IP}"
    echo
    exit 9
  fi 
}




#---------------------------------------------

function disabled_Check_Database() {
  # This fnction is disabled and can be removed.

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
    echo "No!"
    echolog "Kubernetes master: ${REMOTESERVER} was not reachable on SSH (port ${REMOTESSHPORT}). Please check."
    exit 2
  else
    echo "Yes!"
    echolog "Success connecting to Kubernetes master ${REMOTESERVER} on port ${REMOTESSHPORT}."
  fi
}

#---------------------------------------------


function Check_Master_SSH_Command_Execution() {
  echo
  # echo "Check if the user $MASTER_USER is able to run commands on kubernetes master $MASTER_IP."
  # echo "(You may need to accept the fingerprint of the master when this script is run for the first time.)"
  echo "Running command '$1' as user $MASTER_USER on Kubernetes Master $MASTER_IP."
  echo
  ssh -o ConnectTimeout=5 ${MASTER_USER}@${MASTER_IP} "$1"

  if [ $? -gt 0 ]; then
    echolog "There was a problem running '$1' through ${MASTER_USER}@${MASTER_IP} over SSH. Please check."
    exit 9
  fi
}


#---------------------------------------------

function disabled_Show_LB_Status() {
  # This function is disabled and can be removed.

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

  # SERVICE_LIST=$(ssh -o ConnectTimeout=5 ${MASTER_USER}@${MASTER_IP} "kubectl get services --all-namespaces=true | egrep -v '<none>|AGE'" | tr '\n' '\n\r')
  SERVICE_LIST=$(ssh -o ConnectTimeout=5 -n ${MASTER_USER}@${MASTER_IP} "kubectl get services --all-namespaces=true | egrep -v '<none>|AGE'" )

  # Be careful: SSH reads from standard input and eats all remaining lines. Use ssh -n
  # Tip: from http://stackoverflow.com/questions/9393038/ssh-breaks-out-of-while-loop-in-bash

  # There seems to be a problem in the way the kubectl output is formatted. Something wrong with line endings.
  # (Actually it turned out to be a problem caused by SSH. but ayway). 

  # Tip from: http://stackoverflow.com/questions/10929453/read-a-file-line-by-line-assigning-the-value-to-a-variable
  echolog "Following services were found with external IPs - on Kubernetes master ..."


  ORIG_IFS=$IFS

  # Set IFS to null. This is needed for the loop below to work and separate services into separate lines/records.
  IFS=''

  # Sometimes for does not work as expected with output of other programs, such as sqlite.
  # use while intead  # for LINE in  $SERVICE_LIST; do

  echo $SERVICE_LIST | while IFS='' read -r SERVICE_LINE || [[ -n "$SERVICE_LINE" ]]; do

    # Not possible to have  summarzed IP info from kubectl for this service, 
    # because we do not have a namespace and service name yet. We just have one long line.

    echo "===================================================================================================="
    echolog "${SERVICE_LINE}"
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
  ENDPOINTS_IPS=$(ssh -o ConnectTimeout=5 -n ${MASTER_USER}@${MASTER_IP} "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICE}" | egrep -w 'ip' | sed  -e 's/\"//g'  -e 's/ip://g' -e 's/,//g' | tr -d ' ' | tr '\n' ' ' )

  ENDPOINTS_PORT=$(ssh -o ConnectTimeout=5 -n ${MASTER_USER}@${MASTER_IP} "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICE}" | egrep -w 'port' | sed  -e 's/\"//g' -e 's/,//'  | cut -f 2  -d ':'  | tr -d ' '  )

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


function COMPARE_CONFIG_FILES() {
  # It is quite possible that the production config file does not exist when the script is run for the firt time,
  #     such as on a fresh system. In that case checking for that file is not very meaningful. 
  # It does become meaningful though in the subsequent runs, as we need to compare the files.

  echo
  if [ -r $TEMP_HAPROXY_CONF ] && [ -r $PRODUCTION_HAPROXY_CONFIG ]; then
    echo "Comparing generated (haproxy) config with running config ..."
    echo
    diff $TEMP_HAPROXY_CONF $PRODUCTION_HAPROXY_CONFIG
    DIFFERENCE=$?

    echo

    if [ $DIFFERENCE -gt 0 ]; then

      echolog "The generated and running (haproxy) config files differ. Replacing the running haproxy file with the newly generated one, and reloading haproxy service ..."
      cp /etc/haproxy/haproxy.cfg ${PRODUCTION_HAPROXY_CONFIG}.bak
      cp -f $TEMP_HAPROXY_CONF  $PRODUCTION_HAPROXY_CONFIG
    else
      echolog "No difference found between generated and running config."
    fi

    # It is possible that the script is running for the first time, and haproxy service is not running already.
    # In that case, we need to start the service.
    # And, if haproxy is already running, just reload it. 

    echo
    echo "Checking/managing HA Proxy service ..."
    # pidof is not being used in favor of the error code recieved by service's status command. 
    # This is explained in length in the CHECK_FLANNEL section. 
    ## HAPROXY_PID=$(pidof haproxy-systemd-wrapper)

    systemctl status haproxy > /dev/null
    HAPROXY_ERROR_CODE=$?

    # if [ -z "${HAPROXY_PID}" ]; then
    if [ ${HAPROXY_ERROR_CODE} -gt 0 ]; then
      # In this case, it doesn't matter if the config files are same. The service itself is down and needs to be up.
      systemctl start haproxy 
      if [ $? -eq 0 ]; then
        echolog  "HA Proxy process was not running on this system. Starting the service ... Successful."
      else
        echolog  "HA Proxy process was not running on this system. Starting the service ... Failed!"
      fi
    else
      # Once we reach here, check if there were differences , on then we reload service, otherwise we don't.
      if [ $DIFFERENCE -gt 0 ]; then
        # Found differences, and service already running, so reload it.
        echolog "HA Proxy already running on this system. Reloading it ..."
        service haproxy reload
      else
        echolog "HA Proxy already running on this system. Configuration unchanged. Reload is not required."
      fi
    fi

    # also log this service restart thing in the loadbalancer log file.
    # Setup the correct IP addresses on the correct ethernet interface.
    # IP allignment may be needed even if the config files match. So we have to run IP Alignment routine in any case.
    ALIGN_IP_ADDRESSES
  else
    echolog "One of the config files is missing or not readable! Ideally this should never happen! If it does the script code is broken for this scenario! [FIXIT]"
  fi
}


function ALIGN_IP_ADDRESSES() {
  # This function compares the IP addresses on the ethernet interface with the ones in the haproxy config.
  echo
  echo "Aligning IP addresses on ${FOUND_INTERFACE}..."
  # echo "Debug: FOUND_INTERFACE: $FOUND_INTERFACE"
  # echo "Debug: FOUND_IP: $FOUND_IP"
  # echo "Debug: FOUND_SUBNET_BITS: $FOUND_SUBNET_BITS"
  ip addr show dev ${FOUND_INTERFACE} | grep secondary| awk '{print $2'}| cut -f1 -d '/' | sort -n > /tmp/IPs_from_interface.txt
  grep bind $TEMP_HAPROXY_CONF | awk '{print $2'} | cut -f1 -d ':' | sort -n > /tmp/IPs_from_haproxy_config.txt
  IPsToRemove=$(comm -3 /tmp/IPs_from_interface.txt /tmp/IPs_from_haproxy_config.txt | grep -v "[[:space:]]")
  # The command below finds the lines with leading spaces, and then removes the leading spaces to create a list of IPs. 
  IPsToAdd=$(comm -3 /tmp/IPs_from_interface.txt /tmp/IPs_from_haproxy_config.txt | grep "[[:space:]]"  | sed 's/^[[:space:]]//')
  for i in ${IPsToRemove}; do
    echolog "Removing IP address ${i} from the interface ${FOUND_INTERFACE}."
    ip addr del ${i}/${FOUND_SUBNET_BITS} dev ${FOUND_INTERFACE}
  done

  for i in ${IPsToAdd}; do
    echolog  "Adding IP address ${i} to the interface ${FOUND_INTERFACE}."
    ip addr add ${i}/${FOUND_SUBNET_BITS} dev ${FOUND_INTERFACE}
  done
  echo
  echo "Here is the final status of the network interface ${FOUND_INTERFACE} :"
  echo "---------------------------------------------------------------------------------------"
  ip addr show dev $FOUND_INTERFACE
  echo "---------------------------------------------------------------------------------------"
  echo

}




#---------------------------------------------

function AVAILABLE_IPS() {
  # This function prints the top 10 IPs from the availble IPs. This helps in creating kubernets services with external-ips.
  # Needs nmap to be installed on the load balancer.

  # Generate a list of IPs which do not respond on nmap ping scan, and then remove the top and the bottom most lines 
  #    from the output, because those are network and broadcast IPs - unsuable of-course. Display top 10 lines of the final output.
  # Also nmap is intelligent to do a network scan if I provide it the target as myip/mysubnetbits .i,e 192.168.121.201/24 !
  # That is a blessing!

  echo 
  echo "Here are Top 10 IPs from the available pool:"
  echo "--------------------------------------------" 
  nmap -v -sn -n ${LB_PRIMARY_IP}/${FOUND_SUBNET_BITS} -oG - | awk '/Status: Down/{print $2}' | sed '1,1d' | head --lines=-1 | head 
  echo 
}


#---------------------------------------------




function disabled_CREATE_HA_PROXY_CONFIG() {
  ## This function is not used any more, and can be removed.

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

function echolog() {
  MESSAGE=$1
  TIMESTAMP=$(date +'%b %d %T')
  echo "${MESSAGE}"
  echo "${TIMESTAMP} ${MESSAGE}" >> $LB_LOG_FILE 
}


# ------------------------------------

function disabled_WRITE_ENDPOINTS_IN_CONFIG() {
  # This function is not used anymore, and can be removed.
  NAMESPACE=$1
  SERVICENAME=$2


  # SSH to apiserver, get endpoints from api's http interface and parse the options:
  # ENDPOINTS_IPS=$(ssh -o ConnectTimeout=5 -n ${MASTER_USER}@${MASTER_IP} "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICENAME}" | egrep -w 'ip' | sed  -e 's/\"//g'  -e 's/ip://g' -e 's/,//g' ) 
  # ENDPOINTS_PORT=$(ssh -o ConnectTimeout=5 ${MASTER_USER}@${MASTER_IP "curl -k -s  http://localhost:8080/api/v1/namespaces/${NAMESPACE}/endpoints/${SERVICENAME}" | egrep -w 'port' | sed  -e 's/\"//g' -e 's/,//'  | cut -f 2  -d ':' )

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


# -----------------------------------------

function CHECK_LOCK_FILE() {
  # Check file lock. If some other instance of same program is running, exit this instance.
  if [ -r ${LOCK_FILE} ]; then
    echolog "Lock file exists: ${LOCK_FILE} . This means another instance of this program is running. Please ensure that only one instance of this program runs at any given time."
    exit 9
  else
    LB_PID=$(pgrep -o  loadbalancer.sh)
    echo "${LB_PID}" > ${LOCK_FILE}
    echolog "Acquiring program lock with PID: ${LB_PID} , in lock file: ${LOCK_FILE}"
  fi 

}

function DELETE_LOCK_FILE {
  if [ -r ${LOCK_FILE} ]; then
    echolog "Releasing progarm lock: ${LOCK_FILE}"
    rm -f ${LOCK_FILE}
  fi

}



#
###### END - FUNCTIONS ####################


###### START - SANITY CHECKS ##############
#
function SANITY_CHECKS() {
# All sanity checks are combined into a function.
echo
echo "Starting Sanity checks ..."

Check_LB_IP

CHECK_FLANNEL

## Check_Database

Check_Master_SSH_Connectivity

Check_Master_SSH_Command_Execution "uptime"

# cs is abbreviation of componentstatuses! 

Check_Master_SSH_Command_Execution "kubectl get cs"

CHECK_KUBE_SERVICE_FOR_LB_IP

echo
echo "Sanity checks completed successfully!"
echo 
}
#
###### END - SANITY CHECKS #################






#### START - PROGRAM CODE #################
echo
case $1 in 
create)
  Message="Create haproxy configuration."
  echo "Beginning execution of main program - in $1 mode..."
  echo
  CHECK_LOCK_FILE 
  SANITY_CHECKS
  Services_Info_Table create
  COMPARE_CONFIG_FILES
  # Debug: sleep 10
  DELETE_LOCK_FILE
  ;;
show)
  Message="Show load balancer configuration and status."
  # The LB DB is only for it's internal working. There is no need to show a DB, which may have no records, 
  # or records, which are now not in sync with current cluster/services state.
  # Show_LB_Status
  echo "Beginning execution of main program - in $1 mode..."
  echo
  echo "Showing status of service: haproxy"
  echo "----------------------------------"
  systemctl status haproxy -l
  echo
  echo "Showing status of service: flanneld"
  echo "-----------------------------------"
  systemctl status flanneld -l
  echo
  SANITY_CHECKS
  Services_Info_Table show
  AVAILABLE_IPS
  ;;
tests)
  Message="Show possible tests."
  echo "You can perform the following tests / create following scenarios , before starting this script, to see if this script can hold up to what you throw at it."
  echo "Note: All tests need to be performed passing 'create' as an argument to the script."
  echo "1. Try to stop flanneld and haproxy services."
  echo "2. Try to block SSh access to master node, or remove the public key of this server from the authorized_keys file on the master."
  echo "3. Try changing the primary IP address of the load balancer in the loadbalancer.conf file"
  echo "4. Try creating a service in kubernetes using the primary IP address of the load balancer."
  echo "5. Try to add a few IP addresses (of the same IP scheme) on the same interface which has the primary IP address of the load balancer."
  echo "   This should result in removal of these IP addresses from this interface when the script runs."
  echo "6. Try to make any random modifications to the running haproxy config file - /etc/haproxy/haproxy.conf"
  ;;
*)
  Message="Show help."
  echo
  echo "You need to use one of the operations: create|show|tests|help"
  ;;
esac

echo ""
echo "oooooooooooooooooooo $Message - Operation completed. oooooooooooooooooooo" 
echo "Logs are in: ${LB_LOG_FILE}"
echo

echo "TODO:"
echo "-----"
# echo "* - Compare temporary haproxy conf with the one which is running. If different replace the conf file and reload service. "
# echo "* - Add IP management on the LB PRIMARY interface."
# echo "* - Check haproxy service in the beginning. It should be running. A stopped service cannot be reloaded."
echo "* - Use [root@loadbalancer ~]# curl -k -s -u vagrant:vagrant  https://10.245.1.2/api/v1/namespaces/default/endpoints/apache | grep ip"
echo "    The above is better to use instead of getting endpoints from kubectl, because kubectl only shows 2-3 endpoints and says +XX more..."
echo "* - Create multiple listen sections depending on the ports of a service. such as 80, 443 for web servers. This may be tricky. Or there can be two bind commands in one listen directive/section."
# echo "* - Add test for flannel interface to be up"
# echo "* - Add check for the LB primary IP. If it is found in kubernetes service definitions on master, abort program and ask user to fix that first. LB Primary IP must not be used as a external IP in any of the services."
echo "* - Use local kubectl instead of SSHing into Master"
echo
#
##### END - PROGRAM CODE ###################
