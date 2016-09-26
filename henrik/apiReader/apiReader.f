url="localhost:8001"

function jsonValue() {
# Found here :
# https://gist.github.com/cjus/1047794
#
  KEY=$1
  num=$2
  awk -F"[,:}]" '{for(i=1;i<=NF;i++){if($i~/'$KEY'\042/){print $(i+1)}}}' | tr -d '"' | sed -n ${num}p | sort -u | sed 's@.*/@@'
}

function getNodeIPs(){
  echo $(curl -s $url/api/v1/nodes | jsonValue 'address')
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
    echo $(curl -s $url/api/v1/namespaces/$namespace/pods | grep -A 3 "metadata" |  jsonValue 'name')
  else
    echo $(curl -s $url/api/v1/pods | grep -A 3 "metadata" |  jsonValue 'name')
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
