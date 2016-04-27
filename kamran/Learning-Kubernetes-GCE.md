# Running WordPress with a Single Pod
Source: https://cloud.google.com/container-engine/docs/tutorials/hello-wordpress

Prerequisits: 
Install gcloud and kubectl on local computer.


Setup environment:

``` 
[kamran@kworkhorse ~]$ gcloud config list
Your active configuration is: [default]

[compute]
zone = europe-west1-b
[core]
account = kamranazeem@gmail.com
disable_usage_reporting = False
project = learn-kubernetes-1289
[kamran@kworkhorse ~]$ 
``` 


Create new project in google cloud: https://console.cloud.google.com/project

Note: Project cannot be created through gcloud command line. You can list projects though using:

```
[kamran@kworkhorse ~]$ gcloud  projects  list
PROJECT_ID             NAME              PROJECT_NUMBER
learn-kubernetes-1289  Learn-Kubernetes  185358700664
[kamran@kworkhorse ~]$ 


[kamran@kworkhorse ~]$ gcloud  projects  describe  learn-kubernetes-1289 
createTime: '2016-04-22T08:44:46.593Z'
lifecycleState: ACTIVE
name: Learn-Kubernetes
projectId: learn-kubernetes-1289
projectNumber: '185358700664'
[kamran@kworkhorse ~]$ 
``` 


The project ID of the new project is learn-kubernetes-1289

On local computer:
```
gcloud config set project learn-kubernetes-1289
gcloud config set compute/zone europe-west1-b
``` 

Notes: 
* Compute Zones are found here: https://cloud.google.com/compute/docs/zones#available
* Machine types are here: https://cloud.google.com/compute/docs/machine-types 
* Container Engine (Kubernetes) (shows cluster and cluster size, container registry): https://console.cloud.google.com/kubernetes
* Compute Engine (shows VM Instances,CPU usage, Disks, Images, Zones, etc): https://console.cloud.google.com/compute 


``` 
$ gcloud container clusters create hello-world \
    --num-nodes 1 \
    --machine-type g1-small
``` 

I got this:
``` 
[kamran@kworkhorse ~]$ gcloud container clusters create hello-world \
>     --num-nodes 1 \
>     --machine-type g1-small
ERROR: (gcloud.container.clusters.create) ResponseError: code=503, message=Project learn-kubernetes-1289 is not fully initialized with the default service accounts. Please try again later.
[kamran@kworkhorse ~]$ x
``` 

On the web interface, I saw Container Engine initializing, so I waited.

After I got this screen, I executed the command again and I got it working.

``` 
[kamran@kworkhorse ~]$ gcloud container clusters create hello-world     --num-nodes 1     --machine-type g1-small
Creating cluster hello-world...done.
Created [https://container.googleapis.com/v1/projects/learn-kubernetes-1289/zones/europe-west1-b/clusters/hello-world].
kubeconfig entry generated for hello-world.
NAME         ZONE            MASTER_VERSION  MASTER_IP      MACHINE_TYPE  NODE_VERSION  NUM_NODES  STATUS
hello-world  europe-west1-b  1.2.2           146.148.26.51  g1-small      1.2.2         1          RUNNING
[kamran@kworkhorse ~]$ 
``` 

You can check the list of clusters (again) by using:
``` 
[kamran@kworkhorse ~]$ gcloud container clusters list
NAME         ZONE            MASTER_VERSION  MASTER_IP      MACHINE_TYPE  NODE_VERSION  NUM_NODES  STATUS
hello-world  europe-west1-b  1.2.2           146.148.26.51  g1-small      1.2.2         1          RUNNING
[kamran@kworkhorse ~]$ 
``` 

You now have one instance in this project: the worker node that you specified. The kubernetes master, which takes care of pod scheduling and runs the Kubernetes API server, is hosted by Container Engine.

You can visit the Kubernetes web UI by visiting the master IP from the information from  `clusters list` command. 

https://146.148.26.51/ui 

Needs username and password! Where do I get it from? TODO .


The instances list command shows a node / VM . 
``` 
[kamran@kworkhorse ~]$ gcloud compute instances list
NAME                                        ZONE            MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP    STATUS
gke-hello-world-default-pool-06b28f2c-knbh  europe-west1-b  g1-small                   10.132.0.2   130.211.84.95  RUNNING
[kamran@kworkhorse ~]$
``` 

Create pod:
```
[kamran@kworkhorse ~]$ kubectl run wordpress --image=tutum/wordpress --port=80
deployment "wordpress" created
[kamran@kworkhorse ~]$


[kamran@kworkhorse ~]$ kubectl get  deployments 
NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
wordpress   1         1         1            1           24m
[kamran@kworkhorse ~]$ 

[kamran@kworkhorse ~]$ kubectl get pods
NAME                        READY     STATUS    RESTARTS   AGE
wordpress-297829341-naen6   1/1       Running   0          20m
[kamran@kworkhorse ~]$ 
``` 

Get more information about a deployment:
```
[kamran@kworkhorse ~]$ kubectl describe deployments wordpress
Name:			wordpress
Namespace:		default
CreationTimestamp:	Fri, 22 Apr 2016 11:06:27 +0200
Labels:			run=wordpress
Selector:		run=wordpress
Replicas:		1 updated | 1 total | 1 available | 0 unavailable
StrategyType:		RollingUpdate
MinReadySeconds:	0
RollingUpdateStrategy:	1 max unavailable, 1 max surge
OldReplicaSets:		<none>
NewReplicaSet:		wordpress-297829341 (1/1 replicas created)
Events:
  FirstSeen	LastSeen	Count	From				SubobjectPath	Type		Reason			Message
  ---------	--------	-----	----				-------------	--------	------			-------
  24m		24m		1	{deployment-controller }			Normal		ScalingReplicaSet	Scaled up replica set wordpress-297829341 to 1


[kamran@kworkhorse ~]$ 
```




Services:
Right now there is no services defined. We only see the default / built-in kubernetes service. 

```
[kamran@kworkhorse ~]$ kubectl get services
NAME         CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.19.240.1   <none>        443/TCP   29m
[kamran@kworkhorse ~]$ 

[kamran@kworkhorse ~]$ kubectl describe services kubernetes
Name:			kubernetes
Namespace:		default
Labels:			component=apiserver,provider=kubernetes
Selector:		<none>
Type:			ClusterIP
IP:			10.19.240.1
Port:			https	443/TCP
Endpoints:		146.148.26.51:443
Session Affinity:	None
No events.

[kamran@kworkhorse ~]$ 

``` 

Need to expose our wordpress deployment as a service to allow external traffic:
```
[kamran@kworkhorse ~]$ kubectl expose deployment wordpress --type=LoadBalancer
service "wordpress" exposed
[kamran@kworkhorse ~]$ 
``` 

Notice that the service name is same as the name of deployment.

```
[kamran@kworkhorse ~]$ kubectl get services
NAME         CLUSTER-IP     EXTERNAL-IP      PORT(S)   AGE
kubernetes   10.19.240.1    <none>           443/TCP   35m
wordpress    10.19.252.18   130.211.84.161   80/TCP    1m
[kamran@kworkhorse ~]$ 


[kamran@kworkhorse ~]$ kubectl describe services wordpress
Name:			wordpress
Namespace:		default
Labels:			run=wordpress
Selector:		run=wordpress
Type:			LoadBalancer
IP:			10.19.252.18
LoadBalancer Ingress:	130.211.84.161
Port:			<unset>	80/TCP
NodePort:		<unset>	32663/TCP
Endpoints:		10.16.0.7:80
Session Affinity:	None
Events:
  FirstSeen	LastSeen	Count	From			SubobjectPath	Type		Reason			Message
  ---------	--------	-----	----			-------------	--------	------			-------
  1m		1m		1	{service-controller }			Normal		CreatingLoadBalancer	Creating load balancer
  50s		50s		1	{service-controller }			Normal		CreatedLoadBalancer	Created load balancer


[kamran@kworkhorse ~]$ 
``` 

Now visit http://130.211.84.161 and you will see the wordpress installation page. (Screenshot)
user: kamran / daCcutbXDh9JCBb9gb



Cleanup:

``` 
[kamran@kworkhorse ~]$  kubectl delete deployment wordpress
deployment "wordpress" deleted

[kamran@kworkhorse ~]$  kubectl delete services kubernetes
service "kubernetes" deleted
[kamran@kworkhorse ~]$ 

[kamran@kworkhorse ~]$ gcloud container clusters delete hello-world
The following clusters will be deleted.
 - [hello-world] in [europe-west1-b]

Do you want to continue (Y/n)?  Y

Deleting cluster hello-world...done.
Deleted [https://container.googleapis.com/v1/projects/learn-kubernetes-1289/zones/europe-west1-b/clusters/hello-world].
[kamran@kworkhorse ~]$ 

```


# Create a Guestbook with Redis and PHP

Download the guestbook.zip into a directory:

```
[kamran@kworkhorse guestbook-redis-php]$ pwd
/home/kamran/Projects/Personal/learn-kubernetes/guestbook-redis-php

[kamran@kworkhorse guestbook-redis-php]$ ls 
frontend-controller.yaml  guestbook.zip                 redis-master-service.yaml    redis-slave-service.yaml
frontend-service.yaml     redis-master-controller.yaml  redis-slave-controller.yaml
[kamran@kworkhorse guestbook-redis-php]$ 
``` 


Create cluster:
``` 
[kamran@kworkhorse guestbook-redis-php]$ gcloud container clusters create guestbook
Creating cluster guestbook...done.
Created [https://container.googleapis.com/v1/projects/learn-kubernetes-1289/zones/europe-west1-b/clusters/guestbook].
kubeconfig entry generated for guestbook.
NAME       ZONE            MASTER_VERSION  MASTER_IP      MACHINE_TYPE   NODE_VERSION  NUM_NODES  STATUS
guestbook  europe-west1-b  1.2.2           146.148.26.51  n1-standard-1  1.2.2         3          RUNNING
[kamran@kworkhorse guestbook-redis-php]$ 
``` 

Use replication controller to create and start a pod:
```
[kamran@kworkhorse guestbook-redis-php]$  kubectl create -f redis-master-controller.yaml
replicationcontroller "redis-master" created
[kamran@kworkhorse guestbook-redis-php]$ 
``` 

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get pods
NAME                 READY     STATUS    RESTARTS   AGE
redis-master-eipdp   1/1       Running   0          1m
[kamran@kworkhorse guestbook-redis-php]$ 
``` 


Find the name of the node where this pod is running:

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get pods -l name=redis-master -o wide
NAME                 READY     STATUS    RESTARTS   AGE       NODE
redis-master-eipdp   1/1       Running   0          2m        gke-guestbook-default-pool-85b2d116-56vy
[kamran@kworkhorse guestbook-redis-php]$ 
``` 

This will be one of the nodes created by the create cluster command. (The create cluster command created a cluster of 3 nodes - by default).

``` 


``` 




Try SSH into this node:
```
[kamran@kworkhorse guestbook-redis-php]$ gcloud compute ssh  gke-guestbook-default-pool-85b2d116-56vy 
WARNING: The private SSH key file for Google Compute Engine does not exist.
WARNING: You do not have an SSH key for Google Compute Engine.
WARNING: [/usr/bin/ssh-keygen] will be executed to generate a key.
Generating public/private rsa key pair.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /home/kamran/.ssh/google_compute_engine.
Your public key has been saved in /home/kamran/.ssh/google_compute_engine.pub.
The key fingerprint is:
SHA256:o8fN9D0Bx5Q1s6zFRoH/us0JIERm9CY0IMSHpjZ3xG8 kamran@kworkhorse
The key's randomart image is:
+---[RSA 2048]----+
|    ooo.oB    oBo|
|     +.+= o  += +|
|    o o .o o. +* |
|   + . ..Eo  o+. |
|  . o . S... .. .|
|       o =.... ..|
|      . o o ..o. |
|       .      o+.|
|              .oo|
+----[SHA256]-----+
Updated [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289].
Warning: Permanently added '130.211.84.95' (ECDSA) to the list of known hosts.
Warning: Permanently added '130.211.84.95' (ECDSA) to the list of known hosts.
Linux gke-guestbook-default-pool-85b2d116-56vy 3.16.0-4-amd64 #1 SMP Debian 3.16.7-ckt20-1+deb8u4 (2016-02-29) x86_64

Welcome to Kubernetes v1.2.2!

You can find documentation for Kubernetes at:
  http://docs.kubernetes.io/

You can download the build image for this release at:
  https://storage.googleapis.com/kubernetes-release/release/v1.2.2/kubernetes-src.tar.gz

It is based on the Kubernetes source at:
  https://github.com/kubernetes/kubernetes/tree/v1.2.2

For Kubernetes copyright and licensing information, see:
  /usr/local/share/doc/kubernetes/LICENSES

kamran@gke-guestbook-default-pool-85b2d116-56vy:~$ 

```


List docker containers running in this node.

```
kamran@gke-guestbook-default-pool-85b2d116-56vy:~$ sudo docker ps
CONTAINER ID        IMAGE                                                                  COMMAND                  CREATED             STATUS              PORTS               NAMES
496cbc4b4919        redis                                                                  "docker-entrypoint.sh"   6 minutes ago       Up 6 minutes                            k8s_master.ea2b5809_redis-master-eipdp_default_d705eca7-0877-11e6-9e1b-42010af000cf_db5428a9
dd811e72597b        gcr.io/google_containers/pause:2.0                                     "/pause"                 6 minutes ago       Up 6 minutes                            k8s_POD.475a00de_redis-master-eipdp_default_d705eca7-0877-11e6-9e1b-42010af000cf_eccace90
b5c45ef4eb0b        eu.gcr.io/google_containers/kubernetes-dashboard-amd64:v1.0.1          "/dashboard --port=90"   11 minutes ago      Up 10 minutes                           k8s_kubernetes-dashboard.19279401_kubernetes-dashboard-v1.0.1-suz7k_kube-system_1516a734-0877-11e6-9176-42010af000cf_570988b6
a3b9bf62c1e6        eu.gcr.io/google_containers/fluentd-gcp:1.18                           "/bin/sh -c '/usr/sbi"   11 minutes ago      Up 11 minutes                           k8s_fluentd-cloud-logging.5165de6b_fluentd-cloud-logging-gke-guestbook-default-pool-85b2d116-56vy_kube-system_a31ba0629311d10bb74b3e4126d8e7f2_dab8df41
1d50a2e0cc56        gcr.io/google_containers/pause:2.0                                     "/pause"                 11 minutes ago      Up 11 minutes                           k8s_POD.3a1c00d7_kubernetes-dashboard-v1.0.1-suz7k_kube-system_1516a734-0877-11e6-9176-42010af000cf_f89047a3
818caf41b0e3        gcr.io/google_containers/kube-proxy:e6b444aa35fdae9f9f41b8fd8acc60a1   "/bin/sh -c 'kube-pro"   11 minutes ago      Up 11 minutes                           k8s_kube-proxy.c8d4f4be_kube-proxy-gke-guestbook-default-pool-85b2d116-56vy_kube-system_c220b8af61ae8675279db7b7ea5f595e_a0d0d9ab
ec415316a307        gcr.io/google_containers/pause:2.0                                     "/pause"                 11 minutes ago      Up 11 minutes                           k8s_POD.6059dfa2_kube-proxy-gke-guestbook-default-pool-85b2d116-56vy_kube-system_c220b8af61ae8675279db7b7ea5f595e_17d5e716
a915491f4f7b        gcr.io/google_containers/pause:2.0                                     "/pause"                 11 minutes ago      Up 11 minutes                           k8s_POD.6059dfa2_fluentd-cloud-logging-gke-guestbook-default-pool-85b2d116-56vy_kube-system_a31ba0629311d10bb74b3e4126d8e7f2_a745200c
kamran@gke-guestbook-default-pool-85b2d116-56vy:~$ 
```
Notice the redis container (the top most in the list) has the container ID: 496cbc4b4919



``` 
kamran@gke-guestbook-default-pool-85b2d116-56vy:~$ sudo docker images
REPOSITORY                                               TAG                                IMAGE ID            CREATED             VIRTUAL SIZE
redis                                                    latest                             1f4ff6e27d64        16 hours ago        177.5 MB
gcr.io/google_containers/kube-proxy                      e6b444aa35fdae9f9f41b8fd8acc60a1   0b5741dbb335        2 weeks ago         165.6 MB
eu.gcr.io/google_containers/kubernetes-dashboard-amd64   v1.0.1                             cd9ec8830a67        3 weeks ago         44.09 MB
eu.gcr.io/google_containers/heapster                     v1.0.2                             8b67b80f6263        3 weeks ago         96.22 MB
eu.gcr.io/google_containers/addon-resizer                1.0                                186c40870d40        6 weeks ago         36.76 MB
eu.gcr.io/google_containers/fluentd-gcp                  1.18                               ed70ff4ab587        6 weeks ago         411.5 MB
gcr.io/google_containers/pause                           2.0                                8950680a606c        6 months ago        350.2 kB
gcr.io/google_containers/pause                           0.8.0                              3e004fdaffa9        12 months ago       241.7 kB
kamran@gke-guestbook-default-pool-85b2d116-56vy:~$ 
``` 

Exit the node:
``` 
kamran@gke-guestbook-default-pool-85b2d116-56vy:~$ exit
logout
Connection to 130.211.84.95 closed.
[kamran@kworkhorse guestbook-redis-php]$ 
```

Start the Redis master's service

Note: A service is an abstraction which defines a logical set of pods and a policy by which to access them. It is effectively a named load balancer that proxies traffic to one or more pods.

When you set up a service, you tell it the pods to proxy based on pod labels. Note that the pod that you created in step one has the label name=redis-master defined in the file redis-master-controller.yaml .

Now, use the file redis-master-service.yaml to create a service for the Redis master:

The selector field of the service configuration (in redis-master-service.yaml) determines which pods will receive the traffic sent to the service. So, the configuration is specifying that we want this service to point to pods labeled with name=redis-master.

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl create -f redis-master-service.yaml
service "redis-master" created

[kamran@kworkhorse guestbook-redis-php]$ kubectl get services
NAME           CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes     10.27.240.1     <none>        443/TCP    22m
redis-master   10.27.248.198   <none>        6379/TCP   15s

[kamran@kworkhorse guestbook-redis-php]$ kubectl get services -l name=redis-master
NAME           CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
redis-master   10.27.248.198   <none>        6379/TCP   29s
[kamran@kworkhorse guestbook-redis-php]$ 
```

Create redis slaves:

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl create -f redis-slave-controller.yaml
replicationcontroller "redis-slave" created
[kamran@kworkhorse guestbook-redis-php]$ 
```

We now see two replication controllers:
```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get rc
NAME           DESIRED   CURRENT   AGE
redis-master   1         1         20m
redis-slave    2         2         28s
[kamran@kworkhorse guestbook-redis-php]$
```


Check the list of pods:
```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get pods
NAME                 READY     STATUS    RESTARTS   AGE
redis-master-eipdp   1/1       Running   0          22m
redis-slave-zf787    1/1       Running   0          1m
redis-slave-zicbi    1/1       Running   0          1m
[kamran@kworkhorse guestbook-redis-php]$ 
```

Create the Redis worker service:

Set up a service to proxy connections to the Redis read workers. In addition to discovery, the service provides transparent load balancing to clients.


```
[kamran@kworkhorse guestbook-redis-php]$ kubectl create -f redis-slave-service.yaml
service "redis-slave" created
[kamran@kworkhorse guestbook-redis-php]$ 
```


```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get services
NAME           CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes     10.27.240.1     <none>        443/TCP    30m
redis-master   10.27.248.198   <none>        6379/TCP   7m
redis-slave    10.27.252.100   <none>        6379/TCP   31s
[kamran@kworkhorse guestbook-redis-php]$ 
```

Create the guestbook web server pods:
Now that you have the backend of your guestbook up and running, start its frontend web servers.

```
kubectl create -f frontend-controller.yaml
```

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl create -f frontend-controller.yaml
replicationcontroller "frontend" created

[kamran@kworkhorse guestbook-redis-php]$ kubectl get rc
NAME           DESIRED   CURRENT   AGE
frontend       3         3         9s
redis-master   1         1         28m
redis-slave    2         2         7m
[kamran@kworkhorse guestbook-redis-php]$ 
```

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get pods
NAME                 READY     STATUS              RESTARTS   AGE
frontend-lmezo       0/1       ContainerCreating   0          51s
frontend-mktst       0/1       ContainerCreating   0          51s
frontend-q30cg       0/1       ContainerCreating   0          51s
redis-master-eipdp   1/1       Running             0          28m
redis-slave-zf787    1/1       Running             0          8m
redis-slave-zicbi    1/1       Running             0          8m
[kamran@kworkhorse guestbook-redis-php]$ 
```

Create a guestbook web service with an external IP:

As with the other pods, we want a service to group the guestbook server pods. However, this time it's different: this service is user-facing, so we want it to be externally visible. That is, we want a client to be able to request the service from outside the cluster. To accomplish this, we can set the type: LoadBalancer field in the service configuration (defined in frontend-service.yaml) .


```
[kamran@kworkhorse guestbook-redis-php]$ kubectl create -f frontend-service.yaml
service "frontend" created
[kamran@kworkhorse guestbook-redis-php]$
```

In few minutes you will see an IP address:

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get services
NAME           CLUSTER-IP      EXTERNAL-IP      PORT(S)    AGE
frontend       10.27.250.194   130.211.80.100   80/TCP     1m
kubernetes     10.27.240.1     <none>           443/TCP    37m
redis-master   10.27.248.198   <none>           6379/TCP   15m
redis-slave    10.27.252.100   <none>           6379/TCP   8m
[kamran@kworkhorse guestbook-redis-php]$ 
```

Load the page in browser: http://130.211.80.100 , you will see "Guestbook"

(Screen shot)


If (for example) your site becomes popular, you can add more web servers to your frontend.

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl get pods
NAME                 READY     STATUS    RESTARTS   AGE
frontend-lmezo       1/1       Running   0          7m
frontend-mktst       1/1       Running   0          7m
frontend-q30cg       1/1       Running   0          7m
redis-master-eipdp   1/1       Running   0          35m
redis-slave-zf787    1/1       Running   0          15m
redis-slave-zicbi    1/1       Running   0          15m

[kamran@kworkhorse guestbook-redis-php]$ kubectl scale --replicas=5 rc frontend
replicationcontroller "frontend" scaled

[kamran@kworkhorse guestbook-redis-php]$ kubectl get pods
NAME                 READY     STATUS    RESTARTS   AGE
frontend-6hg3l       1/1       Running   0          4s
frontend-9nows       1/1       Running   0          4s
frontend-lmezo       1/1       Running   0          7m
frontend-mktst       1/1       Running   0          7m
frontend-q30cg       1/1       Running   0          7m
redis-master-eipdp   1/1       Running   0          35m
redis-slave-zf787    1/1       Running   0          15m
redis-slave-zicbi    1/1       Running   0          15m
[kamran@kworkhorse guestbook-redis-php]$ 
```


Cleanup:
Delete the frontend service to clean up its external load balancer.

```
[kamran@kworkhorse guestbook-redis-php]$ kubectl delete services frontend
service "frontend" deleted
[kamran@kworkhorse guestbook-redis-php]$ 
```

The following deletes the Google Compute Engine instances that are running the cluster, and all services and pods that were running on them.

```
[kamran@kworkhorse guestbook-redis-php]$ gcloud container clusters delete guestbook
The following clusters will be deleted.
 - [guestbook] in [europe-west1-b]

Do you want to continue (Y/n)?  Y

Deleting cluster guestbook...done.
Deleted [https://container.googleapis.com/v1/projects/learn-kubernetes-1289/zones/europe-west1-b/clusters/guestbook].
[kamran@kworkhorse guestbook-redis-php]$ 

```






