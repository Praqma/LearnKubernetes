# Theory of setting up an external load balancer

* It is possible that a LB machine can be setup with two interfaces. One connected to the infrastructure network, and the other connected to the network where pods are created, i.e. the flannel network. For this reason, I think that the LB will be inside the cluster network, and **not** outside the network. (Think inside the box! :)
* This means that the LB must have flannel client serice running so it can take part in the flannel network. But flannel alone cannot work magic, it's purpose is to assign a subnet to docker0 interface. That means, we are going to need docker too! So that means, we may actually need a Fedora Atomic node which already has flannel and docker both. And each LB will actually be a docker container, with two networks!?
* When we create a service, kubectl assigns a Cluster IP to it. We can take the (infrastructure) IP of the the LB, and insert/provide that to the service definition. However, the Cluster IP only exists virutally, and none of the nodes (inlucding master), have any IP from Cluster IP range assigned on any of the interfaces. That means it is not possible for any machine to learn where a cluster IP resides (ever). This means this (cluster IP) (or the network information about the cluster IP) can never be found in any routing table on any of the machines, and thus can never be reached. 
* This brings us to a point that having a LB and having it DNAT the related traffic to a cluster IP will (probably) *never** work. Instead, we should examine the service in question, extract the **end points** defined in that service definition, and then DNAT traffic from public interface of the LB to the pod network (the end points). For this , we can either use simple Iptables, or a proxy such as ha-proxy or nginx.
* This brings to the next point, that, pods may die at any time and re-created, and the endpoint information in a service definition **will** change. When that happens, the traffic redirection rules on the LB need to be updated. In the beginning, we wil ldo it manually for proof of concept. Later, we can develop some sort of mechanism, that when a service definition changes, we update the proxy redirection rules. 
* Does iptables have a capability to forward a packet to multiple destination addresses? or do I need to have multiple iptables rules for as end-points as there in a service? How will I manage that? Do I need to write some custom interface to iptable and have some sort of database to update the rules, etc?


# Configuration of a Load Balancer
Installed a separate VM with CENTOS (minimum). Assigned it the same networks (192.168.121.0/24) and (10.245.1.0/24) , which kubernetes nodes are using. (Though it seems silly to use two networks for the same purpose -- Investigate/ToDo). I had to manually add a virtual network card to the VM and assign it kubernetes0 network).

Password: root/redhat 
Installed bind-utils, net-tools, flannel - using yum.
```
[root@loadbalancer ~]# yum -y install bind-utils net-tools flannel
```

My Load Balancer VM's network looks like this:

```
[root@loadbalancer ~]# ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 52:54:00:fe:bc:9b brd ff:ff:ff:ff:ff:ff
    inet 10.245.1.142/24 brd 10.245.1.255 scope global dynamic ens9
       valid_lft 3535sec preferred_lft 3535sec
    inet6 fe80::5054:ff:fefe:bc9b/64 scope link 
       valid_lft forever preferred_lft forever
3: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 52:54:00:97:73:d4 brd ff:ff:ff:ff:ff:ff
    inet 192.168.121.201/24 brd 192.168.121.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe97:73d4/64 scope link 
       valid_lft forever preferred_lft forever
[root@loadbalancer ~]# 
```

Routing table looks like this:
```
[root@loadbalancer ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.121.1   0.0.0.0         UG    100    0        0 eth0
0.0.0.0         10.245.1.1      0.0.0.0         UG    101    0        0 ens9
10.245.1.0      0.0.0.0         255.255.255.0   U     100    0        0 ens9
192.168.121.0   0.0.0.0         255.255.255.0   U     100    0        0 eth0
[root@loadbalancer ~]# 
```

I think this is silly for kubernetes to create an additional infrastructure network (10.245.1.0/24) when there already is a infrastructure network (192.168.121.0/24) to which these nodes are connected. (This needs more investigation - ToDo).


I can ping Kubernetes master and worker node on 10.245.1.0/24 network:

```
[root@loadbalancer ~]# ping -c 1 10.245.1.2
PING 10.245.1.2 (10.245.1.2) 56(84) bytes of data.
64 bytes from 10.245.1.2: icmp_seq=1 ttl=64 time=0.457 ms

--- 10.245.1.2 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.457/0.457/0.457/0.000 ms



[root@loadbalancer ~]# ping -c 1 10.245.1.3
PING 10.245.1.3 (10.245.1.3) 56(84) bytes of data.
64 bytes from 10.245.1.3: icmp_seq=1 ttl=64 time=0.495 ms

--- 10.245.1.3 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.495/0.495/0.495/0.000 ms
[root@loadbalancer ~]#
```

I can also ping the kubernetes master and worker node on the 192.168.121.0/24 network:

```
[root@loadbalancer ~]# ping -c 1 192.168.121.91
PING 192.168.121.91 (192.168.121.91) 56(84) bytes of data.
64 bytes from 192.168.121.91: icmp_seq=1 ttl=64 time=0.352 ms

--- 192.168.121.91 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.352/0.352/0.352/0.000 ms
[root@loadbalancer ~]# 



[root@loadbalancer ~]# ping -c 1 192.168.121.185
PING 192.168.121.185 (192.168.121.185) 56(84) bytes of data.
64 bytes from 192.168.121.185: icmp_seq=1 ttl=64 time=0.394 ms

--- 192.168.121.185 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.394/0.394/0.394/0.000 ms
[root@loadbalancer ~]# 
```



On Kubernetes master, I have the following pods running:
```
[vagrant@kubernetes-master ~]$ kubectl get pods
NAME                     READY     STATUS    RESTARTS   AGE
busybox                  1/1       Running   5          1d
centos                   1/1       Running   5          1d
nginx-2040093540-xu5va   1/1       Running   0          2h
[vagrant@kubernetes-master ~]$ 
```



My nginx pod has following basic properties:
```
[vagrant@kubernetes-master ~]$ kubectl describe pod/nginx-2040093540-xu5va | egrep -w "Name:|IP:|Node:"
Name:		nginx-2040093540-xu5va
Node:		kubernetes-node-1/10.245.1.3
IP:		10.246.92.8
[vagrant@kubernetes-master ~]$ 
```


If I try to ping my nginx pod from my load balancer, I am not able to:
```
[root@loadbalancer ~]# ping 10.246.92.8
PING 10.246.92.8 (10.246.92.8) 56(84) bytes of data.
^C
--- 10.246.92.8 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 999ms

[root@loadbalancer ~]#
```

So I need to be a part of flannel network!

# Configure the Load Balancer - flannel:

```
[root@loadbalancer ~]# vi /etc/sysconfig/flanneld 
FLANNEL_ETCD="http://10.245.1.2:4379"
FLANNEL_ETCD_KEY="/coreos.com/network"
```

**NOTE:** Normally etcd runs on port 2379 (and 4001) but this cluster, to which I am trying to add this (proof of concept) load balancer, was setup by the kubernetes' own setup script, using vagrant+libvirt setup. For some really strange reason, the etcd service on kubernetes master is listening on 4379 instead of 2379. Go figure!

(I used `ps aux | grep flannel` on the kubernetes worker node to find out what key is being used by the worker node to contact the etcd instance to setup flannel service .)


I restarted the flannel service, and got it running:
```
[root@loadbalancer ~]# service flanneld restart
Redirecting to /bin/systemctl restart  flanneld.service
[root@loadbalancer ~]# 


[root@loadbalancer ~]# systemctl status flanneld -l
● flanneld.service - Flanneld overlay address etcd agent
   Loaded: loaded (/usr/lib/systemd/system/flanneld.service; disabled; vendor preset: disabled)
   Active: active (running) since Mon 2016-06-20 16:17:04 CEST; 4min 15s ago
  Process: 9849 ExecStartPost=/usr/libexec/flannel/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker (code=exited, status=0/SUCCESS)
 Main PID: 9840 (flanneld)
   CGroup: /system.slice/flanneld.service
           └─9840 /usr/bin/flanneld -etcd-endpoints=http://10.245.1.2:4379 -etcd-prefix=/coreos.com/network

Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.011302 09840 main.go:275] Installing signal handlers
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.013083 09840 main.go:130] Determining IP address of default interface
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.013308 09840 main.go:188] Using 192.168.121.201 as external interface
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.013324 09840 main.go:189] Using 192.168.121.201 as external endpoint
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.017503 09840 etcd.go:204] Picking subnet in range 10.246.1.0 ... 10.246.255.0
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.018609 09840 etcd.go:84] Subnet lease acquired: 10.246.90.0/24
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.034702 09840 udp.go:222] Watching for new subnet leases
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.053001 09840 udp.go:247] Subnet added: 10.246.55.0/24
Jun 20 16:17:04 loadbalancer.example.com flanneld[9840]: I0620 16:17:04.053044 09840 udp.go:247] Subnet added: 10.246.92.0/24
Jun 20 16:17:04 loadbalancer.example.com systemd[1]: Started Flanneld overlay address etcd agent.
[root@loadbalancer ~]# 
```

I think you can see from output above, and have the great feeling that you should be able to ping the nginx pod now, as it has added some subnets from various kubernetes nodes! To have icing on the cake, we can now actually do a ping on the IP of our nginx pod and see if it works!

```
[root@loadbalancer ~]# ping 10.246.92.8
PING 10.246.92.8 (10.246.92.8) 56(84) bytes of data.
64 bytes from 10.246.92.8: icmp_seq=1 ttl=61 time=0.805 ms
^C
--- 10.246.92.8 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.805/0.805/0.805/0.000 ms
[root@loadbalancer ~]# 
```
Hurray! It works! 

----- 

So now we can reach the pod just by setting up flannel on our LB , we know that we don't actually need to have docker on this machine (LB VM). Also, just for completion, here is how the networking on our LB looks like after flannel is setup.


```
[root@loadbalancer ~]# ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN 
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 52:54:00:fe:bc:9b brd ff:ff:ff:ff:ff:ff
    inet 10.245.1.142/24 brd 10.245.1.255 scope global dynamic ens9
       valid_lft 2295sec preferred_lft 2295sec
    inet6 fe80::5054:ff:fefe:bc9b/64 scope link 
       valid_lft forever preferred_lft forever
3: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    link/ether 52:54:00:97:73:d4 brd ff:ff:ff:ff:ff:ff
    inet 192.168.121.201/24 brd 192.168.121.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fe97:73d4/64 scope link 
       valid_lft forever preferred_lft forever
4: flannel0: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1472 qdisc pfifo_fast state UNKNOWN qlen 500
    link/none 
    inet 10.246.90.0/16 scope global flannel0
       valid_lft forever preferred_lft forever
[root@loadbalancer ~]# 
```

Routing table:
```
[root@loadbalancer ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.121.1   0.0.0.0         UG    100    0        0 eth0
0.0.0.0         10.245.1.1      0.0.0.0         UG    101    0        0 ens9
10.245.1.0      0.0.0.0         255.255.255.0   U     100    0        0 ens9
10.246.0.0      0.0.0.0         255.255.0.0     U     0      0        0 flannel0
192.168.121.0   0.0.0.0         255.255.255.0   U     100    0        0 eth0
[root@loadbalancer ~]#
```



Now, we can now have some IPtables redirects :
```
[root@loadbalancer ~]# iptables -t nat -A PREROUTING -p tcp -m tcp -d 192.168.121.201 --dport 80 -j DNAT --to-destination 10.246.92.8

[root@loadbalancer ~]# iptables -t nat -A PREROUTING -p tcp -m tcp -d 10.245.1.142 --dport 80 -j DNAT --to-destination 10.246.92.8
```

Also enable packet forwarding:
```
[root@loadbalancer ~]# echo 1 > /proc/sys/net/ipv4/ip_forward
```


OK, So trying to access the pod from my computer, using loadbalancer , does not work. I see the following connection timeouts:

```
[kamran@kworkhorse kamran]$ curl --connect-timeout 1 192.168.121.201
curl: (28) Connection timed out after 1000 milliseconds


[kamran@kworkhorse kamran]$ curl --connect-timeout 1 10.245.1.142
curl: (28) Connection timed out after 1000 milliseconds
[kamran@kworkhorse kamran]$ 
```

I can see that the load balancer iptables rules are there, and that it receives a packet in the PREROUTING chain:

```
[root@loadbalancer ~]# iptables -t nat -n -L PREROUTING -v
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    1    60 DNAT       tcp  --  *      *       0.0.0.0/0            192.168.121.201      tcp dpt:80 to:10.246.92.8
    1    60 DNAT       tcp  --  *      *       0.0.0.0/0            10.245.1.142         tcp dpt:80 to:10.246.92.8
[root@loadbalancer ~]# 
```


, but it does not reach the pod itself.

```
root@nginx-2040093540-xu5va:/# tcpdump -i any                
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
^C
0 packets captured
0 packets received by filter
0 packets dropped by kernel
root@nginx-2040093540-xu5va:/# 
``` 

Something is interfering with the traffic redirection.

I tried to recreate the service with the external IP as 192.168.121.201, but it did not help either.

```
[vagrant@kubernetes-master ~]$ kubectl delete svc nginx 
service "nginx" deleted


[vagrant@kubernetes-master ~]$ kubectl expose deployment nginx --port=80  --external-ip=192.168.121.201
service "nginx" exposed

[vagrant@kubernetes-master ~]$ kubectl get svc
NAME         CLUSTER-IP       EXTERNAL-IP       PORT(S)   AGE
kubernetes   10.247.0.1       <none>            443/TCP   2d
nginx        10.247.211.121   192.168.121.201   80/TCP    5s
[vagrant@kubernetes-master ~]$
```


Also tried with the other IP address:
```
[vagrant@kubernetes-master ~]$ kubectl delete svc nginx 
service "nginx" deleted


[vagrant@kubernetes-master ~]$ kubectl expose deployment nginx --port=80  --external-ip=10.245.1.142
service "nginx" exposed

[vagrant@kubernetes-master ~]$ kubectl get svc
NAME         CLUSTER-IP       EXTERNAL-IP    PORT(S)   AGE
kubernetes   10.247.0.1       <none>         443/TCP   2d
nginx        10.247.177.156   10.245.1.142   80/TCP    3s
[vagrant@kubernetes-master ~]$ 
```

, and it still does not work.


## Here is why DNAT does not work in this situation:

When my work computer (kworkhorse) is able to reach the LB 192.168.121.201. When my work computer tries to access 192.168.121.201 for port 80, the iptables rules on LB changes the destination address of my packet to 10.246.92.8 , which is the IP of the pod. As soon as the packet's target address is changed, it is kind of lost, because my tech computer does not know how to reach 10.246.92.8 . So any rewritten packets with their destination addresses changed, originating from my computer are lost. They don't know where to go!

One way may be to add the route to flannel network on my local computer and setup 192.168.121.201 as it's gateway.  But that will not be a scalable solution. We can't add routes to all of our clients. That would be really silly. 


So may be we can use a proxy on the LB! We reach the LB, and LB reaches out to the pods, gets the data and brings it back to us!



## Setting up a proxy on our load balancer. 

First we delete the iptables rules we setup earlier on our load balancer.
Then we setup a simple nginx or haproxy on lb.

(.. More coming up! ..)
