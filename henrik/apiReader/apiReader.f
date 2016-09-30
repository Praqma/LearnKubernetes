url="localhost:8001"

function jsonValue() {
# Found here :
# https://gist.github.com/cjus/1047794
#
  KEY=$1
  num=$2
  awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p | sed 's@.*/@@' | awk '{$1=$1};1'
}

function getNodeIPs(){
  local nodename=$1

  if [ ! -z "$nodename" ]; then
    echo $(curl -s $url/api/v1/nodes/$nodename | jsonValue 'address')
  else
    echo $(curl -s $url/api/v1/nodes | jsonValue 'address')
  fi
}

function getNodeNames(){
    echo $(curl -s $url/api/v1/nodes | jsonValue 'externalID')
}

function getServices(){
  local namespace=$1

  if [ ! -z "$namespace" ]; then
    echo $(curl -s $url/api/v1/namespaces/$namespace/services/ | jsonValue 'selfLink')
  else
    echo $(curl -s $url/api/v1/services/ | jsonValue 'selfLink')
  fi
}

function getServiceNodePorts(){
  local namespace=$1
  local service=$2

  if [ ! -z "$namespace" ]; then
    echo $(curl -s $url/api/v1/namespaces/$namespace/services/$service | jsonValue 'nodePort')
  else
    echo $(curl -s $url/api/v1/services/$service | jsonValue 'nodePort')
  fi

}

function getServiceNamespace(){
  local service=$1

  echo $(curl -s $url/api/v1/services/ | grep -B 1 $service |  jsonValue 'namespace')

}

function getPods(){
  local namespace=$1

  if [ ! -z "$namespace" ]; then
    echo $(curl -s $url/api/v1/namespaces/$namespace/pods | jq -r '.items[].metadata.name')
  else
    echo $(curl -s $url/api/v1/pods | jq -r '.items[].metadata.name')
  fi
}

function getPodNamespace(){
  local podName=$1
  echo $(curl -s $url/api/v1/pods | grep -A 3 "$podName" | jsonValue 'namespace')
}

function getPodIp(){
  local podName=$2
  local namespace=$1
  echo $(curl -s $url/api/v1/namespaces/$namespace/pods/$podName | jsonValue 'podIP')
}

function getDeployments(){
  local namespace=$1

  if [ ! -z "$namespace" ]; then
    echo $(curl -s $url/apis/extensions/v1beta1/namespaces/$namespace/deployments | grep -A 3 "metadata" |  jsonValue 'name')
  else
    echo $(curl -s $url/apis/extensions/v1beta1/deployments | grep -A 3 "metadata" |  jsonValue 'name')
  fi

}

function getEventsAll(){
  local namespace=$1

  if [ ! -z "$namespace" ]; then
    curl -s $url/api/v1/watch/namespaces/$namespace/events
  else
    curl -s $url/api/v1/watch/events
  fi

}


function formatEventStream(){
  # http://stackoverflow.com/questions/30272651/redirect-curl-to-while-loop
  while read -r l; do
    resourceVersion=$(echo "$l" | jq -r '.object.metadata.resourceVersion') 
    reason=$(echo "$l" | jq -r '.object.reason')
    message=$(echo "$l" | jq -r '.object.message')
  
    echo "Event ($resourceVersion) ($reason) : $message"
  done < <(getEventsOnlyNew)

}

function getEventsOnlyNew(){
  local namespace=$1

  if [ ! -z "$namespace" ]; then
    local resourceVersion=$(curl -s $url/api/v1/namespaces/$namespace/events | jq -r '.metadata.resourceVersion')
  else
    local resourceVersion=$(curl -s $url/api/v1/events | jq -r '.metadata.resourceVersion')
  fi

  local onlyNew="?resourceVersion=$resourceVersion"

  if [ ! -z "$namespace" ]; then
     curl -s -N  $url/api/v1/watch/namespaces/$namespace/events$onlyNew --stderr -
  else
    curl -s -N $url/api/v1/watch/events$onlyNew --stderr - 
  fi
}

function getPodEventStream(){
  local podname=$1

  if [ ! -z "$podname" ]; then
    curl -s $url/api/v1/watch/pods/$podname
  else
    curl -s $url/api/v1/watch/pods
  fi

}


function getPodEventStreamAll(){
  local podname=$1

  if [ ! -z "$podname" ]; then
    curl -s $url/api/v1/watch/pods/$podname
  else
    curl -s $url/api/v1/watch/pods
  fi

}

function getServiceEventStream(){
    curl -s $url/api/v1/watch/services
}

function getDeploymentEventStream(){
    curl $url/apis/extensions/v1beta1/watch/deployments
}
