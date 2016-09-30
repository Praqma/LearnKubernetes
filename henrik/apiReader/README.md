# ApiReader for Kubernetes
## We wanted a simple library of functions to retrieve data from Kubernetes ApiServer implemented in Bash

First, start the proxy (more advanced connections later) and source the function file.
```
kubectl proxy &
source apiReader.f
```

Now get node IP's by 
```
[hoeghh@localhost apiReader]$ getNodeIPs
10.245.1.3 10.245.1.4
```

Get services, in all namespaces by 
```
hoeghh@localhost apiReader]$ getServices
kubernetes my-nginx weavescope-app heapster kube-dns kubernetes-dashboard monitoring-grafana monitoring-influxdb
``` 

Get services in a specific namespace by 
```
[hoeghh@localhost apiReader]$ getServices default
kubernetes my-nginx weavescope-app
```

Get the ports a pod/service is bound to on nodes when using NodePort from namespace
```
[hoeghh@localhost apiReader]$ getServiceNodePorts my-nginx default
32226
```

get the port a pod/service is bound to in a node when using NodePort
```
[hoeghh@localhost apiReader]$ getServiceNodePorts my-nginx
32226
```


Get the namespace of which the pod lives by 
```
[hoeghh@localhost apiReader]$ getPodNamespace my-nginx-3053829504-04408
default
```

Get all pods across namespaces by 
```
[hoeghh@localhost apiReader]$ getPods
heapster-v1.1.0-2101778418-sxln1 kube-dns-v17.1-ikbih kube-proxy-kubernetes-node-1 kube-proxy-kubernetes-node-2 kubernetes-dashboard-v1.1.1-qgpyc monitoring-influxdb-grafana-v3-css0t my-nginx-3053829504-04408 my-nginx-3053829504-1zyjb weavescope-app-e03n3 weavescope-probe-c5y9l weavescope-probe-ga47i
```

Only get pods in a specific namespace by
```
[hoeghh@localhost apiReader]$ getPods default
my-nginx-3053829504-04408 my-nginx-3053829504-1zyjb weavescope-app-e03n3 weavescope-probe-c5y9l weavescope-probe-ga47i
```

Get the IP of a Pod by
```
hoeghh@localhost apiReader]$ getPodIp default my-nginx-3053829504-04408
10.246.24.3
```

Get Deployments by
```
[hoeghh@localhost apiReader]$ getDeployments
heapster-v1.1.0 my-nginx
```

getDeployments from namespace by
```
[hoeghh@localhost apiReader]$ getDeployments default
my-nginx
```

getEvents by
```
[hoeghh@localhost apiReader]$ getEvents 
{
  "kind": "EventList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/events",
    "resourceVersion": "266"
  },
  "items": [
    {
      "metadata": {
        "name": "kubernetes-node-2.147824c40b65f06a",
        "namespace": "default",
...
...
```

getEvents from namespace by
```
[hoeghh@localhost apiReader]$ getEvents default
{
  "kind": "EventList",
  "apiVersion": "v1",
  "metadata": {
    "selfLink": "/api/v1/namespaces/default/events",
    "resourceVersion": "276"
  },
  "items": [
    {
      "metadata": {
        "name": "my-nginx-2494149703-dukkv.1478252045a3d0d3",
        "namespace": "default",
...
...
```

getPodEventStream by
```
[hoeghh@localhost apiReader]$ getPodEventStream 
{"type":"ADDED","object":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"my-nginx-2494149703-ulx3g","generateName":"my-nginx-2494149703-","namespace":"default","selfLink":"/api/v1/namespaces/default/pods/my-nginx-2494149703-ulx3g","uid":"86c83105-8497-11e6-929d-0800277ad4a8","resourceVersion":"268","creationTimestamp":"2016-09-27T09:48:21Z","labels":{"pod-template-hash":"2494149703","run":"my-nginx"},"annotations":{"kubernetes.io/created-by":"{\"kind\":\"SerializedReference\",\"apiVersion\":\"v1\",\"reference\":{\"kind\":\"ReplicaSet\",\"namespace\":\"default\",\"name\.....
...
...
```

getPodEventStream from one pod by
```
Not working yet
```

getServiceEventStream by
```
[hoeghh@localhost apiReader]$ getServiceEventStream 
{"type":"ADDED","object":{"kind":"Service","apiVersion":"v1","metadata":{"name":"kubernetes","namespace":"default","selfLink":"/api/v1/namespaces/default/services/kubernetes","uid":"04846b7b-8495-11e6-929d-0800277ad4a8","resourceVersion":"7","creationTimestamp":"2016-09-27T09:30:24Z","labels":{"component":"apiserver","provider":"kubernetes"}},"spec":{"ports":[{"name":"https","protocol":"TCP","port":443,"targetPort":443}],"clusterIP":"10.247.0.1","type":"ClusterIP","sessionAffinity":"ClientIP"},"status":{"loadBalancer":{}}}}
...
...
```

getDeploymentEventStream by
```
[hoeghh@localhost apiReader]$ getDeploymentEventStream 
{"type":"ADDED","object":{"kind":"Deployment","apiVersion":"extensions/v1beta1","metadata":{"name":"heapster-v1.1.0","namespace":"kube-system","selfLink":"/apis/extensions/v1beta1/namespaces/kube-system/deployments/heapster-v1.1.0","uid":"1f98330a-8495-11e6-929d-0800277ad4a8","resourceVersion":"109","generation":4,"creationTimestamp":"2016-09-27T09:31:09Z","labels":{"k8s-app":"heapster","kubernetes.io/cluster-service":"true","version":"v1.1.0"},....
...
...
```

