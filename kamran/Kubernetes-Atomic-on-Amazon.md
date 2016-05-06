Reference: http://www.projectatomic.io/docs/gettingstarted/


* Master: 52.58.169.227 (172.31.4.165)
* Node1:  52.58.141.9   (172.31.4.166)
* Node2:  52.58.112.190 (172.31.4.167)

Network provided by Amazon for these nodes is 172.31.0.0/16

Overlay network: 172.16.0.0/12

Service Addresses (assigned to pods ?) ( 10.254.0.0/16 ) (cpnfigured in API service config file on master)


Diable SELinux.

IMPORTANT: On Amazon, PLEASE allow related traffic in the Security group. 




```
ssh -i Downloads/Kubernetes-Cluster-on-Atomic-Oslo.pem fedora@NodeIP

sudo rpm-ostree upgrade && sudo systemctl reboot
```

Create a Registry local cache:
```
docker create -p 5000:5000 \
-v /var/lib/local-registry:/var/lib/registry \
-e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry \
-e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
--name=local-registry registry:2
```

## Configure etcd


## configure services on master


## API server:
# Address range to use for services

TODO: Is this flannel? 
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"


## Start Kubernetes service on master:



## Configure flannel

Change the Overlay network to 172.16.0.0/12  in the confi file.

-bash-4.3# cat flanneld-conf.json 
{
  "Network": "172.16.0.0/12",
  "SubnetLen": 24,
  "Backend": {
    "Type": "vxlan"
  }
}
-bash-4.3# 



Do the following two steps:

Push the value in etcd:

-bash-4.3# curl -L http://localhost:2379/v2/keys/atomic01/network/config -XPUT --data-urlencode value@flanneld-conf.json
{"action":"set","node":{"key":"/atomic01/network/config","value":"{\n  \"Network\": \"172.16.0.0/12\",\n  \"SubnetLen\": 24,\n  \"Backend\": {\n    \"Type\": \"vxlan\"\n  }\n}\n","modifiedIndex":15,"createdIndex":15}}
-bash-4.3# 


Try retrieving the value from etc:

-bash-4.3# curl -L http://localhost:2379/v2/keys/atomic01/network/config | python -m json.tool
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   217  100   217    0     0  31151      0 --:--:-- --:--:-- --:--:-- 36166
{
    "action": "get",
    "node": {
        "createdIndex": 15,
        "key": "/atomic01/network/config",
        "modifiedIndex": 15,
        "value": "{\n  \"Network\": \"172.16.0.0/12\",\n  \"SubnetLen\": 24,\n  \"Backend\": {\n    \"Type\": \"vxlan\"\n  }\n}\n"
    }
}
-bash-4.3# 



# Configure Nodes:

```
vi /etc/sysconfig/docker
## OPTIONS='--registry-mirror=http://192.168.122.10:5000 --selinux-enabled'
OPTIONS='--registry-mirror=http://172.31.4.165:5000 --log-driver=journald'
```




## Flannel config on node:

Make sure that the /etc/sysconfig/flanneld.conf s like the following:

(there is no need to have a trailing /config in the line FLANNEL_ETCD_KEY .)

 
-bash-4.3# cat /etc/sysconfig/flanneld 
# Flanneld configuration options  

# etcd url location.  Point this to the server where etcd runs
FLANNEL_ETCD="http://172.31.4.165:2379"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNEL_ETCD_KEY="/atomic01/network"

# Any additional options that you want to pass
#FLANNEL_OPTIONS=""
 
-bash-4.3# 


------------------------------------------- 

After all nodes (and master) are configured, you should see the following in the network layer:

Master:

-bash-4.3# ip a 
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 06:81:d6:64:ca:e3 brd ff:ff:ff:ff:ff:ff
    inet 172.31.4.165/20 brd 172.31.15.255 scope global dynamic eth0
       valid_lft 2331sec preferred_lft 2331sec
    inet6 fe80::481:d6ff:fe64:cae3/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:c6:60:15:55 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
-bash-4.3# 



Nodes:
-bash-4.3# ip a 
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 06:ce:17:bf:45:ed brd ff:ff:ff:ff:ff:ff
    inet 172.31.4.166/20 brd 172.31.15.255 scope global dynamic eth0
       valid_lft 2945sec preferred_lft 2945sec
    inet6 fe80::4ce:17ff:febf:45ed/64 scope link 
       valid_lft forever preferred_lft forever
3: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether f2:a9:66:01:d3:d4 brd ff:ff:ff:ff:ff:ff
    inet 172.16.45.0/12 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::f0a9:66ff:fe01:d3d4/64 scope link 
       valid_lft forever preferred_lft forever
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:1d:69:9c:3c brd ff:ff:ff:ff:ff:ff
    inet 172.16.45.1/24 scope global docker0
       valid_lft forever preferred_lft forever
-bash-4.3# 



-bash-4.3# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 06:25:28:d1:1a:a3 brd ff:ff:ff:ff:ff:ff
    inet 172.31.4.167/20 brd 172.31.15.255 scope global dynamic eth0
       valid_lft 3021sec preferred_lft 3021sec
    inet6 fe80::425:28ff:fed1:1aa3/64 scope link 
       valid_lft forever preferred_lft forever
3: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether fe:37:e9:90:db:9c brd ff:ff:ff:ff:ff:ff
    inet 172.16.26.0/12 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::fc37:e9ff:fe90:db9c/64 scope link 
       valid_lft forever preferred_lft forever
4: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UP group default 
    link/ether 02:42:6f:0e:be:ff brd ff:ff:ff:ff:ff:ff
    inet 172.16.26.1/24 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:6fff:fe0e:beff/64 scope link 
       valid_lft forever preferred_lft forever
6: veth0f7d95d@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue master docker0 state UP group default 
    link/ether aa:95:4b:61:76:a6 brd ff:ff:ff:ff:ff:ff link-netnsid 0
-bash-4.3# 



------------------- 

## Routing tables from master and nodes:


Master:

-bash-4.3# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.31.0.1      0.0.0.0         UG    100    0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
172.31.0.0      0.0.0.0         255.255.240.0   U     100    0        0 eth0
-bash-4.3# 


Node 1:

-bash-4.3# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.31.0.1      0.0.0.0         UG    100    0        0 eth0
172.16.0.0      0.0.0.0         255.240.0.0     U     0      0        0 flannel.1
172.16.45.0     0.0.0.0         255.255.255.0   U     0      0        0 docker0
172.31.0.0      0.0.0.0         255.255.240.0   U     100    0        0 eth0
-bash-4.3# 


Node2:

-bash-4.3# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.31.0.1      0.0.0.0         UG    100    0        0 eth0
172.16.0.0      0.0.0.0         255.240.0.0     U     0      0        0 flannel.1
172.16.26.0     0.0.0.0         255.255.255.0   U     0      0        0 docker0
172.31.0.0      0.0.0.0         255.255.240.0   U     100    0        0 eth0
-bash-4.3# 








----------------------------------------- 





Kubernetes controller = 3 components (apiserver, scheduler, replication controller) Node = Kubelet (which talks to docker) , proxy , docker 

The first host, fed-master, will be the Kubernetes master, and will run the following:

    kube-apiserver,
    kube-controller-manager
    kube-scheduler.
    etcd

Note: etcd can run on a different host but this guide assumes that etcd and Kubernetes master run on the same host.

The remaining host, fed-node will be the node and run the following:

    kubelet,
    proxy
    docker.










```
docker tag pullvoice-tomcat:latest \
  ec2-52-51-123-41.eu-west-1.compute.amazonaws.com:5000/pullvoice-tomcat:latest
```

```
kubectl expose rc nginx --port=80 --target-port=80 --external-ip=52.50.170.242 -l run=nginx
```


Note: Disable ServiceAccount in admission controls.




