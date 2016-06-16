# Kubernetes-on-Fedora-Atomic-on-KVM

This Howto is an attempt to replicate a would-be bare-metal installation. This is done on KVM (not on AWS or GCE).

* Our domain for infrastructure hosts: example.com
* kube-master 192.168.124.10
* kube-node1: 192.168.124.11
* kube-node2: 192.168.124.12


Following : [http://www.projectatomic.io/docs/quickstart/](http://www.projectatomic.io/docs/quickstart/)
There is a guide from RedHat as well! : [https://access.redhat.com/documentation/en/red-hat-enterprise-linux-atomic-host/7/getting-started-with-containers/chapter-5-troubleshooting-kubernetes](https://access.redhat.com/documentation/en/red-hat-enterprise-linux-atomic-host/7/getting-started-with-containers/chapter-5-troubleshooting-kubernetes)


## Login problem
The login to console still does not work properly, even though we have password stored in the user-data file in cloud-init. However since I put my SSH key in it, it is able to login through SSH. Though I have to find the IP address it obtained from the network.

TODO: Improve console login, using: 
* [https://coreos.com/os/docs/latest/cloud-config.html](https://coreos.com/os/docs/latest/cloud-config.html)
* [https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting](https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting)

```
[root@kworkhorse ~]# nmap -sP 192.168.124.0/24

Starting Nmap 7.12 ( https://nmap.org ) at 2016-06-02 14:09 CEST
Nmap scan report for 192.168.124.58
Host is up (0.00019s latency).
MAC Address: 52:54:00:05:BB:EA (QEMU virtual NIC)
Nmap scan report for 192.168.124.1
Host is up.
Nmap done: 256 IP addresses (2 hosts up) scanned in 2.54 seconds
[root@kworkhorse ~]# 
```

```
[kamran@kworkhorse fedora-atomic-cloud-init]$ ssh fedora@192.168.124.58
The authenticity of host '192.168.124.58 (192.168.124.58)' can't be established.
ECDSA key fingerprint is SHA256:Z619UHp/qO+N6Fk9AFumxaKtt9G0VV8peFzTu+yyzyQ.
ECDSA key fingerprint is MD5:af:a7:66:84:aa:8b:8f:9d:3a:fb:4a:dd:c6:b0:28:c6.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.124.58' (ECDSA) to the list of known hosts.
[fedora@localhost ~]$ 
``` 

After, logging in through SSH, I notice that the password to fedora is not assigned:

```
[fedora@localhost ~]$ sudo -i
-bash-4.3# cat /etc/shadow

root:!locked::0:99999:7:::
bin:*:16854:0:99999:7:::
daemon:*:16854:0:99999:7:::
adm:*:16854:0:99999:7:::
lp:*:16854:0:99999:7:::
sync:*:16854:0:99999:7:::
shutdown:*:16854:0:99999:7:::
halt:*:16854:0:99999:7:::
mail:*:16854:0:99999:7:::
operator:*:16854:0:99999:7:::
games:*:16854:0:99999:7:::
ftp:*:16854:0:99999:7:::
nobody:*:16854:0:99999:7:::
fedora:!!:16954:0:99999:7:::
-bash-4.3# 
```

Anyway, moving on.

# Prepare host:
You only need to setup fixed IP and hostname manually by loggin on to each node. Rest of the setup will be handled by the setup-cluster.sh script.

* Assign proper hostname (kube-master.example.com) (/etc/hostname)
* Assign proper IP (192.168.124.10)
* Disable SELinux (/etc/selinux/config)
* Setup SSH key in root user's authorized_keys file. (This is not necessary if you plan to setup the cluster by hand). Also not necessary if you are happy to include a "sudo" with every command you want to execute on the cluster nodes.

```
[fedora@kube-master ~]$ sudo cp /home/fedora/.ssh/authorized_keys /root/.ssh/authorized_keys
```
* Update OS (# rpm-ostree upgrade)
* Optional: Change boot order in KVM. (Not necessary). Note: DO NOT remove CDROM device. (This will result in the node taking too long to boot - at all !)
* Reboot




# Setup Kubernetes related services on Master and worker nodes
Reference: [http://www.projectatomic.io/docs/gettingstarted/](http://www.projectatomic.io/docs/gettingstarted/)
Also: [https://github.com/Praqma/LearnKubernetes/blob/master/kamran/Kubernetes-Atomic-on-Amazon-VPC.md](https://github.com/Praqma/LearnKubernetes/blob/master/kamran/Kubernetes-Atomic-on-Amazon-VPC.md)


## Create Local Docker Registry on Master:
TODO: Fill up here from the other Howto.


# Setup etcd on Master
Todo: fill up from other howto.

## Setup Kubernetes sub-components on master:

* config
* apiserver


## Enable and start the Kubernetes services on Master

## Configure flanel overlay network on Master

## Configure SkyDNS on Master

Please see [SettingUp-SkyDNS.md](SettingUp-SkyDNS.md)

# Configure Worker nodes
## Configuring Docker to use the cluster registry cache


## Configuring Docker to use the Flannel overlay

## Configure Docker to use DNS too

## enable services on nodes:


Result:

```
[fedora@kube-master ~]$ kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
[fedora@kube-master ~]$ 
```

```
[fedora@kube-master ~]$ sudo kubectl get nodes
NAME             STATUS    AGE
192.168.124.11   Ready     1m
192.168.124.12   Ready     1m
[fedora@kube-master ~]$ 
```


---- 

# Basic communication tests:
Run some containers and do basic network testing / pod reachability, etc.

On the master node, create a file: run-my-nginx.yaml with the following contents:

```
[fedora@kube-master ~]$ cat run-my-nginx.yaml 
# From: http://kubernetes.io/docs/user-guide/connecting-applications/ 
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: my-nginx
spec:
  replicas: 2
  template:
    metadata:
      labels:
        run: my-nginx
    spec:
      containers:
      - name: my-nginx
        image: nginx
        ports:
        - containerPort: 80
```


Create the deployment with two pods, defined in the file above.

```
[fedora@kube-master ~]$ kubectl create -f ./run-my-nginx.yaml 
```

This may take a couple of minutes untill the pods are running on nodes. This is because each worker node needs to pull a local copy of the docker image needed for the pods, mentioned in the deployment config file (above).

```
[fedora@kube-master ~]$ kubectl get deployments
NAME       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
my-nginx   2         2         2            2           1h
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl get pods
NAME                        READY     STATUS    RESTARTS   AGE
my-nginx-3800858182-fcglh   1/1       Running   0          1m
my-nginx-3800858182-lx5i2   1/1       Running   0          1m
[fedora@kube-master ~]$
```



Lets check the IPs of these pods and the nodes they are created on.

```
[fedora@kube-master ~]$ kubectl describe pods  -l run=my-nginx| egrep "Name:|Node:|IP:"
Name:		my-nginx-3800858182-fcglh
Node:		192.168.124.12/192.168.124.12
IP:		172.16.18.2

Name:		my-nginx-3800858182-lx5i2
Node:		192.168.124.11/192.168.124.11
IP:		172.16.39.2
[fedora@kube-master ~]$ 
```

Note the following:
* One pod is on node1 and the other is on node2. 
* The pod on node1 has the IP 172.16.18.2
* The pod on node2 has teh IP 172.16.39.2 

## Ping from master:
Lets ping these pods from Master node, and each worker node. 

From the master you can only ping the IPs of the worker nodes, because all cluster machines are on the same subnet (192.168.124.0/24) . 
You cannot ping pods from the master node, becuase master node does not have flannel interface. This is shown below.

```
[fedora@kube-master ~]$ ping -c1 192.168.124.11
PING 192.168.124.11 (192.168.124.11) 56(84) bytes of data.
64 bytes from 192.168.124.11: icmp_seq=1 ttl=64 time=0.220 ms

--- 192.168.124.11 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.220/0.220/0.220/0.000 ms


[fedora@kube-master ~]$ ping -c1 192.168.124.12
PING 192.168.124.12 (192.168.124.12) 56(84) bytes of data.
64 bytes from 192.168.124.12: icmp_seq=1 ttl=64 time=0.297 ms

--- 192.168.124.12 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.297/0.297/0.297/0.000 ms
[fedora@kube-master ~]$ 
```

Lets ping the IP of pods, from master node. This WILL NOT work.

```
[fedora@kube-master ~]$ ping -c1 172.16.18.2
PING 172.16.18.2 (172.16.18.2) 56(84) bytes of data.
^C
--- 172.16.18.2 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 0ms

[fedora@kube-master ~]$ ping -c1 172.16.39.2
PING 172.16.39.2 (172.16.39.2) 56(84) bytes of data.
^C
--- 172.16.39.2 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 0ms

[fedora@kube-master ~]$ 
```

So the pods are not pingable from the master node, becuase the master node does not have the flannel network setup on it. It's routing table does not have information about the subnets belonging to the pods (the flannel network). And since you cannot ping the pods, you cannot reach their services either, such as getting the web page from nginx pods.

Here is some network information from master node:
```
[fedora@kube-master ~]$ ip addr sh
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:05:bb:ea brd ff:ff:ff:ff:ff:ff
    inet 192.168.124.10/24 brd 192.168.124.255 scope global ens3
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe05:bbea/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether 02:42:93:8f:1a:a4 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:93ff:fe8f:1aa4/64 scope link 
       valid_lft forever preferred_lft forever
23: vethe5a10d2@if22: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default 
    link/ether 32:11:f3:06:4b:bf brd ff:ff:ff:ff:ff:ff link-netnsid 0
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.124.1   0.0.0.0         UG    100    0        0 ens3
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.124.0   0.0.0.0         255.255.255.0   U     100    0        0 ens3
[fedora@kube-master ~]$ 
```

## Accessing pods from within the nodes:

You can see that the pods are accessible from both worker nodes:
```
[fedora@kube-node1 ~]$ ping -c1 172.16.18.2
PING 172.16.18.2 (172.16.18.2) 56(84) bytes of data.
64 bytes from 172.16.18.2: icmp_seq=1 ttl=63 time=0.356 ms

--- 172.16.18.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.356/0.356/0.356/0.000 ms
[fedora@kube-node1 ~]$ ping -c1 172.16.39.2
PING 172.16.39.2 (172.16.39.2) 56(84) bytes of data.
64 bytes from 172.16.39.2: icmp_seq=1 ttl=64 time=0.077 ms

--- 172.16.39.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.077/0.077/0.077/0.000 ms
[fedora@kube-node1 ~]$ 
```


```
[fedora@kube-node2 ~]$ ping -c1 172.16.39.2
PING 172.16.39.2 (172.16.39.2) 56(84) bytes of data.
64 bytes from 172.16.39.2: icmp_seq=1 ttl=63 time=0.730 ms

--- 172.16.39.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.730/0.730/0.730/0.000 ms
[fedora@kube-node2 ~]$ ping -c1 172.16.18.2
PING 172.16.18.2 (172.16.18.2) 56(84) bytes of data.
64 bytes from 172.16.18.2: icmp_seq=1 ttl=64 time=0.040 ms

--- 172.16.18.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.040/0.040/0.040/0.000 ms
[fedora@kube-node2 ~]$ 
```


```
[fedora@kube-node1 ~]$ curl http://172.16.18.2
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>


[fedora@kube-node1 ~]$ curl http://172.16.39.2
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
[fedora@kube-node1 ~]$ 
```

Same results are achieved when I access these pods from the second node.


# Creating and accessing the service:
We now have pods running nginx in a flat, cluster wide, address space. In theory, you could talk to these pods directly, but what happens when a node dies? The pods die with it, and the Deployment will create new ones, with different IPs. This is the problem a Service solves.

A Kubernetes Service is an abstraction which defines a logical set of Pods running somewhere in your cluster, that all provide the same functionality. When created, each Service is assigned a unique IP address (also called clusterIP). This address is tied to the lifespan of the Service, and will not change while the Service is alive. Pods can be configured to talk to the Service, and know that communication to the Service will be automatically load-balanced out to some pod that is a member of the Service.

The above deployement can simply be "exposed" using the following command:

```
kubectl expose deployment my-nginx
```

The above command is equivalent of the following service definition:
```
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  labels:
    run: my-nginx
spec:
  ports:
  - port: 80
    protocol: TCP
  selector:
    run: my-nginx
```




```
[fedora@kube-master ~]$ kubectl expose deployment/my-nginx 
service "my-nginx" exposed
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl get services
NAME         CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
kubernetes   10.254.0.1       <none>        443/TCP   3d
my-nginx     10.254.122.172   <none>        80/TCP    23s
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl describe service my-nginx
Name:			my-nginx
Namespace:		default
Labels:			run=my-nginx
Selector:		run=my-nginx
Type:			ClusterIP
IP:			10.254.122.172
Port:			<unset>	80/TCP
Endpoints:		172.16.18.2:80,172.16.39.2:80
Session Affinity:	None
No events.

[fedora@kube-master ~]$ 
```

Whenever a services is created without specifying a "type", then kubernetes uses "ClusterIP" as the default type. This creates an IP from the ServiceAddresses directive in apiserver (configured on master) and attaches it to the newly created service. (Other two types are NodeIP and LoadBalancer) .


## Accessing the cluster IP from master and worker nodes:

Master node is still not able to communicate directly with the cluster IP. Worker nodes can access/communicate with the ClusterIP. This is shown below:

```
[fedora@kube-master ~]$ curl http://10.254.122.172
^C
[fedora@kube-master ~]$ 
```


```
[fedora@kube-node1 ~]$ curl http://10.254.122.172
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
[fedora@kube-node1 ~]$ 
```


[fedora@kube-node2 ~]$ curl http://10.254.122.172
<title>Welcome to nginx!</title>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>
[fedora@kube-node2 ~]$ 
```

Note: I noticed some lag (and indefinite wait) sometimes with I tried to communicate with the cluster IP from the worker nodes.


Please note that this clusterIP is mapped against a particular port. This means, the trying to access this ClusterIP over other protocols, etc, WILL NOT work. e.g. ping to cluster IP will ALWAYS fail.

```[fedora@kube-node1 ~]$ ping 10.254.217.10
PING 10.254.217.10 (10.254.217.10) 56(84) bytes of data.
^C
--- 10.254.217.10 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 999ms

[fedora@kube-node1 ~]$
```


 




