# Kubernetes on bare metal - CENTOS

## References:
* http://kubernetes.io/docs/getting-started-guides/centos/centos_manual_config/
* http://kubernetes.io/docs/user-guide/walkthrough/
* http://kubernetes.io/docs/user-guide/walkthrough/k8s201/
* https://github.com/kubernetes/kubernetes/tree/release-1.2/examples/guestbook/
* http://blog.kubernetes.io/2015/10/some-things-you-didnt-know-about-kubectl_28.html



## Pre-requisit:
Need to machines with CENTOS (7) (64 bit) installed on them. For this example, these are named "centos-master" and "centos-minion" . 

## Summary:
This guide will only get ONE node working. Multiple nodes requires a functional networking configuration done outside of kubernetes (flannel ?).

The Kubernetes package provides a few services: 
* kube-apiserver, 
* kube-scheduler, 
* kube-controller-manager, 
* kubelet, 
* kube-proxy. 

These services are managed by systemd and the configuration resides in a central location: /etc/kubernetes. 

We will break the services up between the hosts. The first host, centos-master, will be the Kubernetes master. This (master) host will run the kube-apiserver, kube-controller-manager, and kube-scheduler and etcd. The remaining host, centos-minion will be the "node" and run kubelet, proxy, cadvisor and docker. 

* centos-master: kube-apiserver, kube-controller-manager, and kube-scheduler, etcd
* centos-minion: kubelet, proxy, cadvisor, docker 

## Host setup:

Hostnames should be same accross the Kubernetes cluster. Hav ethe following in /etc/hosts on all hosts of the cluster. (You can use IP of your choice - ofcourse!).

``` 
$ cat /etc/hosts
127.0.0.1	localhost	localhost.localdomain
192.168.124.30	centos-master
192.168.124.31	centos-minion
```

## Package installation:
All hosts will need an additional yum repository to be setup. Create a file /etc/yum.repos.d/virt7-docker-common-release.repo on all hosts, with the following content:

```
 $ sudo vi /etc/yum.repos.d/virt7-docker-common-release.repo 
 [virt7-docker-common-release]
 name=virt7-docker-common-release
 baseurl=http://cbs.centos.org/repos/virt7-docker-common-release/x86_64/os/
 gpgcheck=0
```


Install the kubernetes and etcd packages on master node:

```
 $ sudo yum -y install --enablerepo=virt7-docker-common-release kubernetes etcd
```

Note: The document on Kubernetes website says that installing the kubernetes package installs etcd as well, which is not correct. You need to install etcd separately , so I just compbined it with the yum command above.


The Kubernetes document says that kubernetes will pull the package cadvisor but that is also not correct.  Cadvisor is obsoleted by the pacakge kubernetes.

```
 [root@centos-master ~]# yum -y install --enablerepo=virt7-docker-common-release cadvisor
 Loaded plugins: fastestmirror
 Loading mirror speeds from cached hostfile
  * base: ftp.uninett.no
  * extras: ftp.uninett.no
  * updates: ftp.uninett.no
 Package cadvisor-0.4.1-0.3.git6906a8ce.el7.x86_64 is obsoleted by kubernetes-1.2.0-0.9.alpha1.gitb57e8bd.el7.x86_64 which is already installed
 Nothing to do
 [root@centos-master ~]# 
```



Install the kubernetes package on minion node:

```
$ sudo yum -y install --enablerepo=virt7-docker-common-release kubernetes
```

Note: The package kubernetes installs the following dependencies:

```
Dependencies Resolved

 ================================================================================================================================================
 Package                                 Arch                   Version                                            Repository              Size
 ================================================================================================================================================
Installing:
 kubernetes                              x86_64                 1.2.0-0.9.alpha1.gitb57e8bd.el7                    extras                  34 k
Installing for dependencies:
 audit-libs-python                       x86_64                 2.4.1-5.el7                                        base                    69 k
 checkpolicy                             x86_64                 2.1.12-6.el7                                       base                   247 k
 docker                                  x86_64                 1.9.1-25.el7.centos                                extras                  13 M
 docker-forward-journald                 x86_64                 1.9.1-25.el7.centos                                extras                 824 k
 docker-selinux                          x86_64                 1.9.1-25.el7.centos                                extras                  70 k
 kubernetes-client                       x86_64                 1.2.0-0.9.alpha1.gitb57e8bd.el7                    extras                 9.3 M
 kubernetes-master                       x86_64                 1.2.0-0.9.alpha1.gitb57e8bd.el7                    extras                  15 M
 kubernetes-node                         x86_64                 1.2.0-0.9.alpha1.gitb57e8bd.el7                    extras                 9.3 M
 libcgroup                               x86_64                 0.41-8.el7                                         base                    64 k
 libselinux-python                       x86_64                 2.2.2-6.el7                                        base                   247 k
 libsemanage-python                      x86_64                 2.1.10-18.el7                                      base                    94 k
 policycoreutils-python                  x86_64                 2.2.5-20.el7                                       base                   435 k
 python-IPy                              noarch                 0.75-6.el7                                         base                    32 k
 setools-libs                            x86_64                 3.3.7-46.el7                                       base                   485 k
 socat                                   x86_64                 1.7.2.2-5.el7                                      base                   255 k

Transaction Summary
 ================================================================================================================================================
Install  1 Package (+15 Dependent packages)

Total download size: 49 M
Installed size: 231 M
```

When you install etcd after you have installed kubernetes, it just pulls in etcd package.

```
Dependencies Resolved

 ================================================================================================================================================
 Package                        Arch                             Version                                 Repository                        Size
 ================================================================================================================================================
Installing:
 etcd                           x86_64                           2.2.5-1.el7                             extras                           5.3 M

Transaction Summary
 ================================================================================================================================================
Install  1 Package

Total download size: 5.3 M
Installed size: 27 M
```

## Disable firewall on all hosts:

```
$ sudo systemctl disable iptables-services firewalld
$ sudo systemctl stop iptables-services firewalld
```


## Configure /etc/kubernetes/config on all hosts:
The file `/etc/kubernetes/config` is going to be the same on all hosts (master and nodes) , and will contain the following:

```
 [root@centos-master ~]# cat /etc/kubernetes/config 
 KUBE_LOGTOSTDERR="--logtostderr=true"
 KUBE_LOG_LEVEL="--v=0"
 KUBE_ALLOW_PRIV="--allow-privileged=false"
 KUBE_ETCD_SERVERS="--etcd-servers=http://centos-master:2379"
 [root@centos-master ~]# 
```

## Configure the Kubernetes services on the master:
### Configure `/etc/kubernetes/apiserver` (on master):

```
 [root@centos-master ~]# cat /etc/kubernetes/apiserver
 KUBE_API_ADDRESS="--insecure-bind-address=0.0.0.0"
 KUBE_API_PORT="--port=8080"
 KUBELET_PORT="--kubelet-port=10250"
 KUBE_ETCD_SERVERS="--etcd-servers=http://127.0.0.1:2379"
 KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"
 ## KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota"
 KUBE_API_ARGS=""
 KUBE_MASTER="--master=http://centos-master:8080"
 [root@centos-master ~]# 
```

### Start Kubernetes services on master:
We need to start the etcd, kube-apiserver, kube-controller-manager and kube-scheduler services on master.

```
for SERVICES in etcd kube-apiserver kube-controller-manager kube-scheduler; do 
	systemctl restart $SERVICES
	systemctl enable $SERVICES
	systemctl status $SERVICES 
done
``` 
 
## Configure Kubernetes services on the node/minion:
We need to configure the kubelet and start the kubelet,  kube-proxy and docker services.

### Configure `/etc/kubernetes/kubelet` (on node/minion):

```
 [root@centos-minion ~]# cat /etc/kubernetes/kubelet 
 KUBELET_ADDRESS="--address=0.0.0.0"
 KUBELET_PORT="--port=10250"
 KUBELET_HOSTNAME="--hostname-override=centos-minion"
 KUBELET_API_SERVER="--api-servers=http://centos-master:8080"
 KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=registry.access.redhat.com/rhel7/pod-infrastructure:latest"
 KUBELET_ARGS=""
 [root@centos-minion ~]# 
```

### Start the appropriate services on node (centos-minion):

```
for SERVICES in kube-proxy kubelet docker; do 
    systemctl restart $SERVICES
    systemctl enable $SERVICES
    systemctl status $SERVICES 
done
```

At this point you should be able to see your node from the master. 

```
 [root@centos-master ~]# kubectl get nodes 
 NAME            LABELS                                 STATUS    AGE
 centos-minion   kubernetes.io/hostname=centos-minion   Ready     15s
 [root@centos-master ~]# 
``` 

## Use the cluster!
We can now try to run some containers and see if things work as expected!

### Run an nginx service:

```
 [root@centos-master ~]# kubectl run nginx --image=nginx
 replicationcontroller "nginx" created
 [root@centos-master ~]#
``` 

**Something to look into:** (TODO): kubectl run creates a Deployment named “nginx” on Kubernetes cluster >= v1.2. If you are running older versions, it creates replication controllers instead. If you want to obtain the old behavior, use --generator=run/v1 to create replication controllers. See kubectl run for more details.

Suprisingly our kubectl version is 1.2! :-

```
 [root@centos-master ~]# kubectl version
 Client Version: version.Info{Major:"1", Minor:"2", GitVersion:"v1.2.0", GitCommit:"b57e8bdc7c3871e3f6077b13c42d205ae1813fbd",  GitTreeState:"clean"}
 Server Version: version.Info{Major:"1", Minor:"2", GitVersion:"v1.2.0", GitCommit:"b57e8bdc7c3871e3f6077b13c42d205ae1813fbd",  GitTreeState:"clean"}
 [root@centos-master ~]# 
``` 



Check the replication controllers:

```
 [root@centos-master ~]# kubectl get rc
 CONTROLLER   CONTAINER(S)   IMAGE(S)   SELECTOR    REPLICAS   AGE
 nginx        nginx          nginx      run=nginx   1          19h
 [root@centos-master ~]# 
``` 



Check the output of the `kubectl get pods` command:
```
 [root@centos-master ~]# kubectl get pods
 NAME          READY     STATUS    RESTARTS   AGE
 nginx-dvd0r   0/1       Pending   0          10s
 [root@centos-master ~]#
``` 

You see an nginx pod is created, but you see "0/1" under the READY column and its STATUS as "pending". This is because the cluster is freshly created and it needs to pull nginx image from the internet before it is able to run it. So this will take some time depending on the speed of your internet connection.

The 0/1 means that this pod has a total of 1 container inside it and out of that total number (1) , zero (0) containers are running. 

While you wait, you can check the output of `docker ps`command on centos-minion. 

```
 [root@centos-minion ~]# docker ps
 CONTAINER ID        IMAGE                                                        COMMAND             CREATED             STATUS                PORTS               NAMES
 80eb7e6e2dbe        registry.access.redhat.com/rhel7/pod-infrastructure:latest   "/pod"              3 seconds ago       Up 2  seconds                            k8s_POD.ae8ee9ac_nginx-dvd0r_default_2339b01d-0ae7-11e6-a0a6-525400142c5e_8b187c70
``` 

After some more time has passed you will see nginx container appearing on the minion:

```
 [root@centos-minion ~]# docker ps
 CONTAINER ID        IMAGE                                                        COMMAND                  CREATED              STATUS              PORTS               NAMES
 99cb61b8e07c        nginx                                                        "nginx -g 'daemon off"   22 seconds ago      Up 22 seconds                           k8s_nginx.cd55de23_nginx-dvd0r_default_2339b01d-0ae7-11e6-a0a6-525400142c5e_2ae8ba87

 80eb7e6e2dbe        registry.access.redhat.com/rhel7/pod-infrastructure:latest   "/pod"                   49 seconds ago      Up 48 seconds                           k8s_POD.ae8ee9ac_nginx-dvd0r_default_2339b01d-0ae7-11e6-a0a6-525400142c5e_8b187c70
 [root@centos-minion ~]# 
``` 

When you see the container running, you should have a pod in running state. Check the output of `kubectl get pods` command on the master:

```
 [root@centos-master ~]# kubectl get pods
 NAME          READY     STATUS    RESTARTS   AGE
 nginx-dvd0r   1/1       Running   0          1m
 [root@centos-master ~]# 
``` 
**Some explanation:**
When you ask Kubernetes to run an image as a container, it first creates a replication controller, then creates a pod inside that replication controller and then creates a container inside that pod for you. A pod can have one or more containers inside it. Containers in a pod are deployed together, and are started, stopped, and replicated as a group. 
There can only be one copy of a container running a particular service in one pod. e.g. In one pod there can be only one nginx service running on port 80. If you want to run another nginx on port 80 or apache on port 80 in the same pod, it won't work. Another copy of the same type of service has to go in another pod, which will of-course have it's own IP. This way there are no IP/port conflicts between services. There can  be many containers in one pod, but with running on different ports, such as a pod can have a web server and a MySQL DB server running inside it, since these two services/containers run on two different ports.


From the above description, it is clear that all containers inside a pod share one IP assigned to the pod, and can access each other (within the pod) using *localhost* as their destination. (topic: networking)


You can login directly into a pod by using *exec* command, like so:

```
[root@centos-master ~]# kubectl exec -ti nginx-3o8yn  -- bash
root@nginx-3o8yn:/# 
```





Lets see what is the IP of this pod:

```
[root@centos-master ~]# kubectl get pod nginx-3o8yn -o go-template={{.status.podIP}}
172.17.0.2[root@centos-master ~]#
``` 

We see that the IP of the pod is 172.17.0.2. At the moment, we do not have any mechanism which would take our traffic from any other computer of the 192.168.124.0/24 network and take it to this pod. So for now, we will try to create another pod (using busybox) and try to access this pod's nginx web service using curl/wget from the helper pod (busybox). (Busybox does not have curl!)

``` 
kubectl run -i --tty busybox --image=busybox --restart=Never -- sh 
``` 


``` 
 [root@centos-master ~]# kubectl run -i --tty busybox --image=busybox --restart=Never -- sh
Waiting for pod default/busybox to be running, status is Pending, pod ready: false
(press enter here)

/ # ls
bin   dev   etc   home  proc  root  run   sys   tmp   usr   var
/ # ping 172.17.0.2
PING 172.17.0.2 (172.17.0.2): 56 data bytes
64 bytes from 172.17.0.2: seq=0 ttl=64 time=0.082 ms
^C
--- 172.17.0.2 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max = 0.082/0.082/0.082 ms
/ #

/ # wget  172.17.0.2
Connecting to 172.17.0.2 (172.17.0.2:80)
index.html           100% |*******************************|   612   0:00:00 ETA


/ # cat index.html 
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
/ # 
```



On centon-minion, you should be able to see busybox running as a container:

```
 [root@centos-minion ~]# docker ps
CONTAINER ID        IMAGE                                                        COMMAND                  CREATED             STATUS              PORTS               NAMES
799693ddf3c1        busybox                                                      "sh"                     21 seconds ago      Up 21 seconds                           k8s_busybox.433dee8_busybox_default_d591071f-0b9c-11e6-a0a6-525400142c5e_dd068a05
eaa38c291522        nginx                                                        "nginx -g 'daemon off"   About an hour ago   Up About an hour                        k8s_nginx.cd55de23_nginx-3o8yn_default_2fb92f3f-0b7e-11e6-a0a6-525400142c5e_792dcfec
. . .
. . . 
 [root@centos-minion ~]# 
``` 


When you exit the busybox shell, the pod will take few moments to stop and disappear from the `kubectl get pods` list. Even if it disappears, it will still exist , which you will need to delete manually. 

```
/ # exit

 [root@centos-master ~]# kubectl get pods
 NAME          READY     STATUS    RESTARTS   AGE
 busybox       1/1       Running   0          15s
 nginx-3o8yn   1/1       Running   1          3h

 [root@centos-master ~]# kubectl get pods
 NAME          READY     STATUS    RESTARTS   AGE
 nginx-3o8yn   1/1       Running   1          3h

 [root@centos-master ~]# kubectl get pods -a
 NAME          READY     STATUS      RESTARTS   AGE
 busybox       0/1       Completed   0          24s
 nginx-3o8yn   1/1       Running     1          4h
 
```

Delete the pod:

``` 
 [root@centos-master ~]# kubectl delete pods busybox
 pod "busybox" deleted
 [root@centos-master ~]# 
``` 




Note: Do not do the following as it will try to run busybox as a daemon, which will never work. Busybox does not have any startup script, so as soon as you run it, it exists.

```
 [root@centos-master ~]# kubectl run busybox --image=busybox
 replicationcontroller "busybox" created
 [root@centos-master ~]# 
``` 

Also, related to above, you will see kubectl trying to restart the busybox container again and agian. Notice the ouput of the  `kubectl get pods` on centos-master .

```
 [root@centos-master ~]# kubectl get pods
 NAME            READY     STATUS             RESTARTS   AGE
 busybox-j5cd8   0/1       CrashLoopBackOff   3          49s
 nginx-3o8yn     1/1       Running            1          2h
 [root@centos-master ~]#
``` 


TODO: We can try to forward the port of this pod to our local computer and try browsing the web page using browser on my computer.

The following is not working at the moment.
```
 [root@centos-master ~]# kubectl port-forward nginx-3o8yn 80:80 
 I0426 14:03:53.790608   19013 portforward.go:213] Forwarding from 127.0.0.1:80 -> 80
 I0426 14:03:53.790688   19013 portforward.go:213] Forwarding from [::1]:80 -> 80
 
 ...(indefinite amount of wait, never returning to command prompt)...

``` 


### Delete this pod:
As soon as I delete a pod, we see that the repolication controller starts a new one immediately:

```
 [root@centos-master ~]# kubectl delete pod nginx-3o8yn
 pod "nginx-3o8yn" deleted
 [root@centos-master ~]#

 (Wait few seconds ...)

 [root@centos-master ~]# kubectl get pods
 NAME          READY     STATUS    RESTARTS   AGE
 nginx-l9tyt   1/1       Running   0          7s
 [root@centos-master ~]# 
```

### Check logs of a pod:

```
 [root@centos-master ~]# kubectl logs --tail=20  nginx-l9tyt 
 172.17.0.3 - - [26/Apr/2016:12:16:36 +0000] "GET / HTTP/1.1" 200 612 "-" "Wget" "-"
 [root@centos-master ~]# 
```

### Delete the replication controller for nginx:
The only way to delete the pod is to kill / delete it' replication controller.

```
 [root@centos-master ~]# kubectl delete rc nginx
 replicationcontroller "nginx" deleted
 [root@centos-master ~]# 
``` 


## Create a pod using a pod definitition file:

```
 [root@centos-master ~]# vi pod-nginx.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80

 [root@centos-master ~]# kubectl create -f pod-nginx.yaml
 pod "nginx" created
 [root@centos-master ~]# 
```

As soon as the pod is created, it starts running. But this time a replication controller was not created:

```
 [root@centos-master ~]# kubectl get pods
 NAME      READY     STATUS    RESTARTS   AGE
 nginx     1/1       Running   0          1m
 [root@centos-master ~]# 

 [root@centos-master ~]# kubectl get rc
 [root@centos-master ~]# 
``` 

The same (pod (and a container running inside it]) can be seen on centos-minion:

``` 
 [root@centos-minion ~]# docker ps
CONTAINER ID        IMAGE                                                        COMMAND                  CREATED             STATUS              PORTS               NAMES
29c37ec95831        nginx                                                        "nginx -g 'daemon off"   2 minutes ago       Up 2 minutes                            k8s_nginx.72c3fedf_nginx_default_8d07633f-0ba9-11e6-a0a6-525400142c5e_65a29936
6590b609cc01        registry.access.redhat.com/rhel7/pod-infrastructure:latest   "/pod"                   2 minutes ago       Up 2 minutes                            k8s_POD.c36b0a77_nginx_default_8d07633f-0ba9-11e6-a0a6-525400142c5e_1a749807
 [root@centos-minion ~]# 
```

The new pod has the IP 172.17.0.2 :

```
[root@centos-master ~]# kubectl get pod nginx -o go-template={{.status.podIP}}
172.17.0.2[root@centos-master ~]#
```

We check it using the same busybox trick as shown further above, so I will not repeat it here. It works.

If we delete this pod now, it won't be recreated as there is no replication controller managing it.

```
[root@centos-master ~]# kubectl delete pod nginx
pod "nginx" deleted
[root@centos-master ~]# 

[root@centos-master ~]# kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE

[root@centos-master ~]# kubectl get rc -a
[root@centos-master ~]# 
``` 


## Kubernetes 201

### Labels:
Create a pod description file using label:

```
 [root@centos-master ~]# vi pod-nginx-with-label.yaml

apiVersion: v1
kind: Pod
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx
    ports:
    - containerPort: 80
``` 



Create a pod:

```
 [root@centos-master ~]# kubectl create -f pod-nginx-with-label.yaml 
 pod "nginx" created
 [root@centos-master ~]# 
``` 


List pods with a specific label:

```
 [root@centos-master ~]# kubectl get pods -l app=nginx
 NAME      READY     STATUS    RESTARTS   AGE
 nginx     1/1       Running   0          52s
 [root@centos-master ~]# 
```

Delete the pod:

```
 [root@centos-master ~]# kubectl delete pods nginx
 pod "nginx" deleted
 [root@centos-master ~]# 
``` 

### Replication controller:

You can create individual pods for your application, and as much as you want - just like docker containers. However it is not possible to manage (scale, etc) the pods directly. To be able to manage pods, the pods need to be under control of a replication controller.

A replication controller has a definition of pod built into it, and the number of replicas to maintain (or keep alive). This means, if you are using replication contollers, you do not need to create the pods individually or independently. Replication controller will create then for you.

Create a replication controller definition file:

```
 [root@centos-master ~]# cat replication-controller.yaml 
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-controller
spec:
  replicas: 2
  # selector identifies the set of Pods that this
  # replication controller is responsible for managing
  selector:
    app: nginx
  # podTemplate defines the 'cookie cutter' used for creating
  # new pods when necessary
  template:
    metadata:
      labels:
        # Important: these labels need to match the selector above
        # The api server enforces this constraint.
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
 [root@centos-master ~]# 
```

(It is assumed that there are no pods defined or running at the moment.)

Now create a nginx replication controller using the replication controller definition file you created just now.

``` 
 [root@centos-master ~]# kubectl create -f replication-controller.yaml
 replicationcontroller "nginx-controller" created
 [root@centos-master ~]# 
```

Check the replication controller and the pods:

```
 [root@centos-master ~]# kubectl get rc
CONTROLLER         CONTAINER(S)   IMAGE(S)   SELECTOR    REPLICAS   AGE
nginx-controller   nginx          nginx      app=nginx   2          42s


 [root@centos-master ~]# kubectl get pods
NAME                     READY     STATUS    RESTARTS   AGE
nginx-controller-7dn5q   1/1       Running   0          45s
nginx-controller-m2r4b   1/1       Running   0          45s
 [root@centos-master ~]# 
``` 


On centos-minion, you will see the following when you execute `docker ps` command. Notice two nginx containers:

```
 [root@centos-minion ~]# docker ps
CONTAINER ID        IMAGE                                                        COMMAND                  CREATED             STATUS              PORTS               NAMES
6a2ef9b4727e        nginx                                                        "nginx -g 'daemon off"   2 minutes ago       Up 2 minutes                            k8s_nginx.72c3fedf_nginx-controller-7dn5q_default_8ed4d989-0bb2-11e6-a0a6-525400142c5e_23ef2307
cc8ef2614370        nginx                                                        "nginx -g 'daemon off"   2 minutes ago       Up 2 minutes                            k8s_nginx.72c3fedf_nginx-controller-m2r4b_default_8ed4f6df-0bb2-11e6-a0a6-525400142c5e_e11f4649
e37472a6aea8        registry.access.redhat.com/rhel7/pod-infrastructure:latest   "/pod"                   2 minutes ago       Up 2 minutes                            k8s_POD.c36b0a77_nginx-controller-7dn5q_default_8ed4d989-0bb2-11e6-a0a6-525400142c5e_315c3e30
65f8ea0c4fd9        registry.access.redhat.com/rhel7/pod-infrastructure:latest   "/pod"                   2 minutes ago       Up 2 minutes                            k8s_POD.c36b0a77_nginx-controller-m2r4b_default_8ed4f6df-0bb2-11e6-a0a6-525400142c5e_6547d34c
 [root@centos-minion ~]# 
``` 

Notice that we have one replication controller and two nginx pods. 

Just for fun (and some more understanding), lets find the IP addresses of these pods.

```
[root@centos-master ~]# kubectl get pod nginx-controller-7dn5q  -o go-template={{.status.podIP}}
172.17.0.3

[root@centos-master ~]# kubectl get pod nginx-controller-m2r4b  -o go-template={{.status.podIP}}
172.17.0.2
```

By the way, if you inspect the docker container of this pod on centos-minion, you will not see any IP assigned to the container itself. We use one of the container IDs from the centos-minion and try to inspect it.

```
 [root@centos-minion ~]# docker inspect 6a2ef9b4727e | grep IP
        "LinkLocalIPv6Address": "",
        "LinkLocalIPv6PrefixLen": 0,
        "SecondaryIPAddresses": null,
        "SecondaryIPv6Addresses": null,
        "GlobalIPv6Address": "",
        "GlobalIPv6PrefixLen": 0,
        "IPAddress": "",
        "IPPrefixLen": 0,
        "IPv6Gateway": "",
 [root@centos-minion ~]# 
``` 


This proves that kubernetes manages all aspects of a container ; and a container is always inside a pod! 


### Delete a replication controller:

```
 [root@centos-master ~]# kubectl delete rc nginx-controller
 replicationcontroller "nginx-controller" deleted
 [root@centos-master ~]# 
```


## Services:
In Kubernetes, the service abstraction achieves these goals. A service provides a way to refer to a set of pods (selected by labels) with a single static IP address. It may also provide load balancing, if supported by the provider.

First we re-create the replication controller from the previous section:

```
 [root@centos-master ~]# kubectl create -f replication-controller.yaml
 replicationcontroller "nginx-controller" created
 [root@centos-master ~]#
```

Next we create a service definition file:

```
 [root@centos-master ~]# cat service.yaml 
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  ports:
  - port: 8000 # the port that this service should serve on
    # the container on each pod to connect to, can be a name
    # (e.g. 'www') or a number (e.g. 80)
    targetPort: 80
    protocol: TCP
  # just like the selector in the replication controller,
  # but this time it identifies the set of pods to load balance
  # traffic to.
  selector:
    app: nginx
 [root@centos-master ~]# 
```

Next we create a service using thie service definition file. Notice that the service is using port 8000 just for example, and connects to port 80 of the backend pods.

``` 
 [root@centos-master ~]# kubectl create -f service.yaml
 service "nginx-service" created
 [root@centos-master ~]# 
``` 

Check the services list:

```
 [root@centos-master ~]# kubectl get services
 NAME            CLUSTER_IP      EXTERNAL_IP   PORT(S)    SELECTOR    AGE
 kubernetes      10.254.0.1      <none>        443/TCP    <none>      1d
 nginx-service   10.254.106.53   <none>        8000/TCP   app=nginx   1m
 [root@centos-master ~]# 
``` 

On most providers (and in our setup), the service IPs are not externally accessible. The easiest way to test that the service is working is to create a busybox pod and exec commands on it remotely. TODO. 

TODO: Tried to do the following but it did not work. I was not able to reach the nginx service on 192.168.124.40 from my computer:

```
[root@centos-master ~]# kubectl expose service nginx-service --external-ip 192.168.124.40 --port=8000 --target-port=80  --name=nginx-8000
service "nginx-8000" exposed
[root@centos-master ~]#


[root@centos-master ~]# kubectl get services
NAME            CLUSTER_IP       EXTERNAL_IP      PORT(S)    SELECTOR    AGE
kubernetes      10.254.0.1       <none>           443/TCP    <none>      1d
nginx-8000      10.254.168.150   192.168.124.40   8000/TCP   app=nginx   3s
nginx-service   10.254.106.53    <none>           8000/TCP   app=nginx   19m
[root@centos-master ~]#
```


==================

If there are multiple containers in a pod, e.g, nginx, redis, mysql, etc, then you can connect to those containers on their shell, using the names defined in the replication controller's definition file. 

$ kubectl exec helloworld-v1-xyzabc -c nginx -- uname -a 

In the command above, "uname -a" is the command to be run on a container named nginx in the helloworld-v1-xyzabc pod. 


Check logs of a container:
$ kubectl logs -f helloworld-v1-xyzabc -c nginx 



You can schedule/allocate resources using cgroups, etc. You can also introduce health endpoints. (reference Kelsey's presentation "strangloop" Sept 25-26 2015.)



Jonathan camp (Service discovery) 







