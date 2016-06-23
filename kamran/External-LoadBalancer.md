# Theory of setting up an external load balancer

* It is possible that a LB machine can be setup with two interfaces. One connected to the infrastructure network, and the other connected to the network where pods are created, i.e. the flannel network. For this reason, I think that the LB will be inside the cluster network, and **not** outside the network. (Think inside the box! :) 
* This means that the LB must have flannel client service running so it can take part in the flannel network. But flannel alone cannot work magic, it's purpose is to assign a subnet to docker0 interface. That means, we are going to need docker too! So that means, we may actually need a Fedora Atomic node which already has flannel and docker both. And each LB will actually be a docker container, with two networks!?
* When we create a service, kubectl assigns a Cluster IP to it. We can take the (infrastructure) IP of the the LB, and insert/provide that to the service definition. However, the Cluster IP only exists virutally, and none of the nodes (inlucding master), have any IP from Cluster IP range assigned on any of the interfaces. That means it is not possible for any machine to learn where a cluster IP resides (ever). This means this (cluster IP) (or the network information about the cluster IP) can never be found in any routing table on any of the machines, and thus can never be reached. 
* This brings us to a point that having a LB and having it DNAT the related traffic to a cluster IP will (probably) *never** work. Instead, we should examine the service in question, extract the **end points** defined in that service definition, and then DNAT traffic from public interface of the LB to the pod network (the end points). For this , we can either use simple Iptables, or a proxy such as ha-proxy or nginx.
* This brings to the next point, that, pods may die at any time and re-created, and the endpoint information in a service definition **will** change. When that happens, the traffic redirection rules on the LB need to be updated. In the beginning, we wil ldo it manually for proof of concept. Later, we can develop some sort of mechanism, that when a service definition changes, we update the proxy redirection rules. 
* Does iptables have a capability to forward a packet to multiple destination addresses? or do I need to have multiple iptables rules for as end-points as there in a service? How will I manage that? Do I need to write some custom interface to iptable and have some sort of database to update the rules, etc?


# Installation of necessary software on the Load Balancer
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

DNAT is normally used on gateway routers. e.g. Consider situation when you have a web server on a private IP scheme behind a router (such as a home router). Your router has a public IP on it's public interface, but on the inside interface, it has private IPs, and one of the IPs is your web server. You setup DNAT rule on the router that any traffic coming in for port 80 should be redirected towards the webserver on the private IP. The webserver responds with a web page and the traffic goes out from the same router again.

Consider a client computer somewhere on the internet having an IP address (123.45.67.89) tries to access this website of yours through the public IP of your router, which is of-course resolved from the DNS such as www.example.com. The sees that the packet has arrived on it's public interface and is destined for port 80. The router sees that it has a DNAT rule for such situation and applies that to the incoming packet. The router changes the destination IP address of the incoming packet (destined for port 80), and forwards the modified packet to the webserver on the private network. Note that the source address of this packet is still that of the client on the internet, i.e. 123.45.67.89. The webserver sees that a packet has arrived seeking a web responce. The web server sends back a responce by using the source address as the destination address. Note that this packet now has the client's IP (123.45.67.89) as destination and the web server's private IP as the source. And, since it has the client's IP in it's destination, it will try to go out the default gateway of this private network, which fortunately is the gateway router itself. The gateway router remembers that it sent out such a DNAT packet earlier, and when it sees this packet coming back, it sort of un-DNATs it. This means that the reponce packet's source will now be replaced with the gateway/router's IP address and the packet will be sent back to the client (123.45.67.89) , and everyone is happy!.


(Phew! That is a lot of explanation!).


In my solution above, I have setup a load balancer "inside" the kubernetes network, and using that as a DNAT jump-box so to speak. When I send out a request from my work computer for the IP of load balancer on port 80, it sees that it should DNAT it to the IP address of the nginx pod. So it rewrites the destination IP address with the (private) IP address of the pod, and sends it out towards the pod. The pod only knows about one and only one private IP address it is connected to. So when it sees such a packet, it tries to respond to it and a packet is sent back using the client IP address as the destination and the pod's IP as the source IP. Since the pod can only send a packet out using it's default gateway, it sends it towards it's default gateway which is the flannel network. The flannel network's default gateway doesn't know about this packet. It does not remember sending such a packet in the first place, so this packet is dropped. At least that is the theory!

One more solution to solve this 3-way routing problem may be to use an additional SNAT rule at the LB. This SNAT will change the source address of the outgoing packet with the IP address of the LB's flanel interface IP, going towards the pod. This way, when pod replies with a responce, it sends it reaches back to the LB, instead of going out the default GW of the kubernetes cluster! [Investigate /ToDo]




Now in our situation, I am trying to reach 192.168.121.201 on port 80 through my (client) IP address 192.168.121.1  . The nginx pod should at least register/show a packet arriving for port 80. 

A successful curl directly from the LB shows packets in tcpdump on the nginx pod.

```
root@nginx-2040093540-xu5va:/# tcpdump -n  -i any 'tcp dst port 80'
tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
20:52:43.055143 IP 10.246.90.0.32869 > 10.246.92.8.80: Flags [S], seq 3628377688, win 28640, options [mss 1432,sackOK,TS val 24237346 ecr 0,nop,wscale 6], length 0
20:52:43.055513 IP 10.246.90.0.32869 > 10.246.92.8.80: Flags [.], ack 2398702889, win 448, options [nop,nop,TS val 24237347 ecr 41170222], length 0
20:52:43.055674 IP 10.246.90.0.32869 > 10.246.92.8.80: Flags [P.], seq 0:75, ack 1, win 448, options [nop,nop,TS val 24237347 ecr 41170222], length 75
20:52:43.056253 IP 10.246.90.0.32869 > 10.246.92.8.80: Flags [.], ack 239, win 465, options [nop,nop,TS val 24237347 ecr 41170222], length 0
20:52:43.056310 IP 10.246.90.0.32869 > 10.246.92.8.80: Flags [.], ack 851, win 484, options [nop,nop,TS val 24237347 ecr 41170222], length 0
20:52:43.057126 IP 10.246.90.0.32869 > 10.246.92.8.80: Flags [F.], seq 75, ack 851, win 484, options [nop,nop,TS val 24237348 ecr 41170222], length 0
20:52:43.057405 IP 10.246.90.0.32869 > 10.246.92.8.80: Flags [.], ack 852, win 484, options [nop,nop,TS val 24237349 ecr 41170223], length 0
```
Note: The IP 10.246.90.0 showing as source IP in the packet capture above is the IP address of the flannel0 interface on my LB.

But a curl from my work computer does not give me anything, and it times out. 

```
[kamran@kworkhorse kamran]$ curl --connect-timeout 2 192.168.121.201
curl: (28) Connection timed out after 2000 milliseconds
[kamran@kworkhorse kamran]$ 
```

```
root@nginx-2040093540-xu5va:/# tcpdump -n  -v -X -i any 'tcp dst port 80'
tcpdump: listening on any, link-type LINUX_SLL (Linux cooked), capture size 262144 bytes
^C
0 packets captured
0 packets received by filter
0 packets dropped by kernel
root@nginx-2040093540-xu5va:/# 
```


I also suspect that maybe some weird/crazy iptables setup on the worker-nodes  (done by kubernetes) is preventing the traffic to reach the web server pod when I use DNAT. There are many rules on a node, with crazy chains and it is a bit difficult to parse through them in a short amount of time. 


So for the time being, ....may be we can use a proxy on the LB! We reach the LB, and LB reaches out to the pods, gets the data and brings it back to us! No address changes, no packet mangling, and hopefully that makes everyone happy. 


# Install and configuration of HAProxy on the load balancer:

First we delete the iptables rules we setup earlier on our load balancer.
Then we setup a simple nginx or haproxy on lb.

Remove all the iptables rules on LB:
```
[root@loadbalancer ~]# iptables -t nat -F ; iptables -F
```

Install HAProxy:
```
[root@loadbalancer ~]# yum -y install haproxy
```

Configure (r)syslog to receive logs from haproxy:
```
[root@loadbalancer ~]# vi /etc/sysconfig/rsyslog 
SYSLOGD_OPTIONS="-r"

[root@loadbalancer ~]# vi /etc/rsyslog.conf 
. . .
local2.*                       /var/log/haproxy.log


[root@loadbalancer ~]# service rsyslog restart

[root@loadbalancer ~]# service rsyslog status
Redirecting to /bin/systemctl status  rsyslog.service
● rsyslog.service - System Logging Service
   Loaded: loaded (/usr/lib/systemd/system/rsyslog.service; enabled; vendor preset: enabled)
   Active: active (running) since Tue 2016-06-21 10:06:04 CEST; 3s ago
 Main PID: 11957 (rsyslogd)
   CGroup: /system.slice/rsyslog.service
           └─11957 /usr/sbin/rsyslogd -n -r

Jun 21 10:06:04 loadbalancer.example.com systemd[1]: Starting System Logging Service...
Jun 21 10:06:04 loadbalancer.example.com systemd[1]: Started System Logging Service.
[root@loadbalancer ~]# 
``` 

## Configure HAProxy:
```
[root@loadbalancer ~]# vi /etc/haproxy/haproxy.cfg
global
    log         127.0.0.1 local2
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon
    stats socket /var/lib/haproxy/stats
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000
frontend  main *:80
    stats enable
    stats uri /haproxy?stats
    default_backend nginx-pods
backend nginx-pods
    balance    roundrobin
    server  pod1 10.246.92.8:80 check
[root@loadbalancer ~]# 
```

Start the haproxy service:
```
[root@loadbalancer ~]# service haproxy restart
Redirecting to /bin/systemctl restart  haproxy.service


[root@loadbalancer ~]# service haproxy status  -l
Redirecting to /bin/systemctl status  -l haproxy.service
● haproxy.service - HAProxy Load Balancer
   Loaded: loaded (/usr/lib/systemd/system/haproxy.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2016-06-21 10:18:55 CEST; 2s ago
 Main PID: 12031 (haproxy-systemd)
   CGroup: /system.slice/haproxy.service
           ├─12031 /usr/sbin/haproxy-systemd-wrapper -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid
           ├─12032 /usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -Ds
           └─12033 /usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -Ds

Jun 21 10:18:55 loadbalancer.example.com systemd[1]: Started HAProxy Load Balancer.
Jun 21 10:18:55 loadbalancer.example.com systemd[1]: Starting HAProxy Load Balancer...
Jun 21 10:18:55 loadbalancer.example.com haproxy-systemd-wrapper[12031]: haproxy-systemd-wrapper: executing /usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -Ds
[root@loadbalancer ~]#
```

Moment of truth - access the Load Balancer from my work computer:
```
[kamran@kworkhorse kamran]$ curl --connect-timeout 2 192.168.121.201
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
[kamran@kworkhorse kamran]$ 
```


Here are the logs from the pod itself:
```
[vagrant@kubernetes-master ~]$ kubectl log nginx-2040093540-xu5va 
. . . 
10.246.90.0 - - [21/Jun/2016:08:19:06 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.43.0" "192.168.121.1"
```



# Using iptables instead of haproxy: (aka - Like a Boss!)

So I wanted this to work with iptables (really badly), and not with haproxy, just so I could prove that this could also be done this way, so I did the following:

## First - Stop HAProxy:
```
[root@loadbalancer ~]# service haproxy stop
Redirecting to /bin/systemctl stop  haproxy.service
[root@loadbalancer ~]# 
```

Verify that we are **not** able to access the nginx pod from our work computer, after we have stopped haproxy.
```
[kamran@kworkhorse kamran]$ curl --connect-timeout 2 192.168.121.201
curl: (7) Failed to connect to 192.168.121.201 port 80: Connection refused
[kamran@kworkhorse kamran]$ 
```



## Create a simple iptables.sh file:
```
[root@loadbalancer ~]# vi iptables.sh
#!/bin/bash

LB_PUBLIC_IP=192.168.121.201

echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A PREROUTING -p tcp -d ${LB_PUBLIC_IP} --dport 80 -j DNAT --to 10.246.92.8:80
iptables -t nat -A POSTROUTING -p tcp -o flannel0 -j MASQUERADE
[root@loadbalancer ~]# 

[root@loadbalancer ~]# chmod +x iptables.sh 
```

## Run the script and verify that the iptables rules are in place:
```
[root@loadbalancer ~]# ./iptables.sh 
```

```
[root@loadbalancer ~]# iptables -t nat -L -n
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination         
DNAT       tcp  --  0.0.0.0/0            192.168.121.201      tcp dpt:80 to:10.246.92.8:80

Chain INPUT (policy ACCEPT)
target     prot opt source               destination         

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination         

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination         
MASQUERADE  tcp  --  0.0.0.0/0            0.0.0.0/0           

[root@loadbalancer ~]# iptables-save 
# Generated by iptables-save v1.4.21 on Wed Jun 22 10:25:46 2016
*filter
:INPUT ACCEPT [56063:4999869]
:FORWARD ACCEPT [50:3969]
:OUTPUT ACCEPT [76361:5167777]
COMMIT
# Completed on Wed Jun 22 10:25:46 2016
# Generated by iptables-save v1.4.21 on Wed Jun 22 10:25:46 2016
*nat
:PREROUTING ACCEPT [2:223]
:INPUT ACCEPT [1:88]
:OUTPUT ACCEPT [2:162]
:POSTROUTING ACCEPT [2:162]
-A PREROUTING -d 192.168.121.201/32 -p tcp -m tcp --dport 80 -j DNAT --to-destination 10.246.92.8:80
-A POSTROUTING -o flannel0 -p tcp -j MASQUERADE
COMMIT
# Completed on Wed Jun 22 10:25:46 2016
[root@loadbalancer ~]# 
```

## Access the nginx pod through work computer - Moment of truth!
```
[kamran@kworkhorse kamran]$ curl --connect-timeout 2 192.168.121.201
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
[kamran@kworkhorse kamran]$ 
```


This is what I get from the pod's logs:
```
[vagrant@kubernetes-master ~]$ kubectl log nginx-2040093540-xu5va -f 
. . . 
10.246.90.0 - - [22/Jun/2016:08:29:10 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.43.0" "-"
```
So the IP logged in the nginx access log is the IP address of the flannel0 interface of my LB.

Hurray! It works!


**We never lose!**



# More notes / future work:
* So the iptables DNAT (and SNAT) works beautifully, sending traffic towards one target IP. I need to investigate if we can use multiple IPs as a target for DNAT. That way I do not have to write multiple DNAT rules for all the destination pods. If it doesn't work i.e. if the multiple IP addresses are not supported, I just have to create a Iptables "named chain" for each type of traffic and in each chain, I will have multiple DNAT rules for each individual target pod.
* Henrik suggests that instead of hitting pods from LB, why don't we try to hit the service IP from LB? That way we do not have to go through  creating a mechanism for service discovery and managing haproxy configuration generation, or IPTables rules management. This is a great idea. But there is a reason I did not go down that path when I started working on LB. The thing is, the cluster IP network is only reachable through worker-nodes and pods and that "cluster network" is not setup on any nodes, nor on LB. So the only reachable items were pods, so I took the path of extracting the service endpoints from a service and then trying to reach them instead. More observations about this are:
** The IPs belonging to the Services/PortalNetwork are not implemented on any interface on any node. So the routing table of any node does not know about the service IPs. How would we make a LB reach a sevrice IP?
**  The kubernetes master node cannot reach a service IP, even when it (the master) is part of the kubernetes pod/flannel network. Only (pods runing on) nodes are able to do so. Why? There are some crazy IPTables rules on nodes, which help achieve this. May be I need to reverse engineer that to use that in my LB?
** Make diagrams on how this whole thing (LoadBalancer) works, based on work done in this document.

 


