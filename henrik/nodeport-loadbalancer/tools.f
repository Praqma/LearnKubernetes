source ../apiReader/apiReader.f

function createLoadBalancer(){
  local Services=$(getServices default | tr " " "\n")
  local Nodes=$(getNodeNames)
  local nodeIP=""
  local line=""

  rm -f *.conf 
  rm -f *.bal 

  echo "<VirtualHost *:80>
        ProxyRequests off

        ServerName example.org
        ProxyPreserveHost On

        IncludeOptional conf.d/*.bal" > kubernetes.services.conf
 

  printf '%s\n' "$Services" | (while IFS= read -r line
  do
    createServiceLB "$line" "$Nodes" & 
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

        IncludeOptional conf.d/*.prox
</VirtualHost>" >> kubernetes.services.conf

} 

function createServiceLB(){
  local Service=$1
  local Nodes=$(echo $2 | tr " " "\n")
  local line=""

  local ServicePort=$(getServiceNodePorts $Service "default")
  local Endpoints=$(getServiceEndpoints $Service "default")

  if [ ! "$ServicePort" == "null" ] && [ ! "$Endpoints" == "" ]; then
    echo "        <Proxy balancer://$Service>" > $Service.service.bal

    printf '%s\n' "$Nodes" | while IFS= read -r line
    do
      local nodeIP=$(getNodeIPs $line)
      echo "                BalancerMember http://$nodeIP:$ServicePort" >> $Service.service.bal
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
        ProxyPassReverse /$Service balancer://$Service" >> $Service.service.bal
  fi
}
