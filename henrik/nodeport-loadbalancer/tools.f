source ../apiReader/apiReader.f

function createLoadBalancer(){
  local LBType=$1

  # Setting LBType to apache, if not specified
  if [ -z "$LBType" ];then
     echo "Setting Loadbalancer type to Apache (default"
     LBType="apache"
  fi

  rm -f *.conf 
  rm -f *.bl 

  if [ "$LBType" = "apache" ]; then
    createLBApache
  elif [ "$LBType" = "haproxy"  ]; then
    createLBHaproxy
  fi
} 

function createLBHaproxy(){
  local Services=$(getServices default | tr " " "\n")
  local Nodes=$(getNodeNames)
  local nodeIP=""
  local line=""

  echo "global
        stats timeout 30s" > haproxy.conf

  echo "defaults
        log     global
        mode    http
        option  httplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
        " >> haproxy.conf

  printf '%s\n' "$Services" | (while IFS= read -r line
  do
    createServiceLBHaproxy "$line" "$Nodes" & 
    done
    wait
  )

#  echo "<SERVICES>" >> haproxy.conf

  echo "listen stats *:1936
    stats enable
    stats uri /stats
    stats hide-version
    stats auth admin:Praqma" >> haproxy.conf  

    $(cat *.bl >> haproxy.conf)
    rm -f *.bl
}

function createServiceLBHaproxy(){
  local Service=$1
  local Nodes=$(echo $2 | tr " " "\n")
  local line=""
  local i=0

  local ServicePort=$(getServiceNodePorts $Service "default")
  local Endpoints=$(getServiceEndpoints $Service "default")

  if [ ! "$ServicePort" == "null" ] && [ ! "$Endpoints" == "" ]; then
    echo "
frontend $Service
    bind *:$ServicePort
    mode http
    default_backend "$Service"_BackEnds
    " >> $Service.service.bl


    echo "backend "$Service"_BackEnds
    mode http
    balance roundrobin
    option forwardfor
    http-request set-header X-Forwarded-Port %[dst_port]
    http-request add-header X-Forwarded-Proto https if { ssl_fc }
    option httpchk HEAD / HTTP/1.1\r\nHost:localhost    " >> $Service.service.bl

    i=0
    printf '%s\n' "$Nodes" | while IFS= read -r line
    do
      local nodeIP=$(getNodeIPs $line)
      echo "    server "$Service"_node"$i" $nodeIP:$ServicePort check" >> $Service.service.bl
      i=$((i+1))
    done
  fi

}

function createLBApache(){
  local Services=$(getServices default | tr " " "\n")
  local Nodes=$(getNodeNames)
  local nodeIP=""
  local line=""

  echo "<VirtualHost *:80>
        ProxyRequests off

        ServerName example.org
        ProxyPreserveHost On

        IncludeOptional conf.d/*.bl" > kubernetes.services.conf


  printf '%s\n' "$Services" | (while IFS= read -r line
  do
    createServiceLBApache "$line" "$Nodes" &
    done
    wait
  )

  echo "        # balancer-manager
        # This tool is built into the mod_proxy_balancer
        # module and will allow you to do some simple
        # modifications to the balanced group via a gui
        # web interface.
        <Location /balancer-manager>
                SetHandler balancer-manager

                # I recommend locking this one down to your
                # your office
                # Require host example.org

        </Location>

        # Point of Balance
        # This setting will allow to explicitly name the
        # the location in the site that we want to be
        # balanced, in this example we will balance "/"
        # or everything in the site.
        ProxyPass /balancer-manager !

</VirtualHost>" >> kubernetes.services.conf

}

function createServiceLBApache(){
  local Service=$1
  local Nodes=$(echo $2 | tr " " "\n")
  local line=""

  local ServicePort=$(getServiceNodePorts $Service "default")
  local Endpoints=$(getServiceEndpoints $Service "default")

  if [ ! "$ServicePort" == "null" ] && [ ! "$Endpoints" == "" ]; then
    echo "        <Proxy balancer://$Service>" > $Service.service.bl

    printf '%s\n' "$Nodes" | while IFS= read -r line
    do
      local nodeIP=$(getNodeIPs $line)
      echo "                BalancerMember http://$nodeIP:$ServicePort" >> $Service.service.bl
    done

    echo "
                # Security technically we arent blocking
                # anyone but this is the place to make
                # those changes.
                #Order Allow
                #Require all granted
                # In this example all requests are allowed.

                # Load Balancer Settings
                # We will be configuring a simple Round
                # Robin style load balancer.  This means
                # that all webheads take an equal share of
                # of the load.
                ProxySet lbmethod=byrequests
        </Proxy>

        ProxyPass /$Service balancer://$Service
        ProxyPassReverse /$Service balancer://$Service" >> $Service.service.bl
  fi
}
