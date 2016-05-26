# Kubernetes on Amazon VPC - using Fedora Atomic OS

Objective is to setup a three (3) node Kubernetes cluster, having one master and two worker nodes (formerly known as minions) - inside a VPC (Virtual Private Cloud) in AWS. This will (hopefully) enable us to use Amazon's Load Balancer services (which are only available for setups done with VPC). 

Reference: [http://www.projectatomic.io/docs/gettingstarted/](http://www.projectatomic.io/docs/gettingstarted/) 
Note: The reference uses virt-manager virtualization, but I am using Amazon AWS do do this lab.

# Part 1: Preparation

# Step 1: Create a VPC in AWS
Have a look at this introductory video from Amazon: [https://youtu.be/jcyZmj6Ywh4](https://youtu.be/jcyZmj6Ywh4)
Log on to Amazon AWS and create a VPC with only one public subnet. It is in the AWS->Services tab. This is the first option out of four types of VPCs you can create. It should have the the following characterstics.


* Name: VPC-ServerNet
* VPC CIDR: 10.0.0.0/16 
* DNS resolution: yes
* DNS hostnames: yes
* Public subnet name: Public Subnet - ServerNet
* Public subnet CIDR: 10.0.0.0/24 
* Auto Assign Public IPs: yes (this is not entirely necessary, you can say no here too. Since it is VPC with one public subnet, it makes sense to say yes here)

Note: This will **not** be a default VPC. 

When you create the subnet it will get its own IDs assigned to it by Amazon. The names you assign are just for better readability.


# Step 2: Create instances in EC2
It is time to create three EC2 instances (VMs) of type M3.Medium . First, you need to find the AMI (Amazon Machine Image) you want to use. We are going to use Fedora Atomic and that has an AMI ID: ami-0bbf5c64 . 

Note: I use EU central / Frankfurt. Your AMI may be different if you are in a different zone or want to use a different zone.

Once you have your AMI ID, you create three EC2 instances using this AMI. Go ahead and use the Launce Instance button to start the wizard which will take you through the steps to create these instances.

![AWS-Instance-Creation-with-VPC](AWS-Instance-Creation-with-VPC)

When you reach the security group tab/section of the Instance creation wizard, make sure that you create a new Security Group and give it a proper name, such as SG-ServerNet. Allow necessary traffic by setting up rules in this security zone. (You can always edit the rules of the security group at a later time). I have setup All Traffic from 0.0.0.0/0 allowed to come in to this security group. This is just a lab setup , which will be deleted in few hours. You can tighten these as you desire. I will probably add some more ports at a later stage.

It will take a while for Amazon to create the instances and get them ready for use. (Have some tea, or do whatever you want :)

Note: The nodes will be assigned IPs from the public subnet you configured for the VPC. In our case the master gets 10.0.0.135/24 . It is not really a public IP, I know. But the real public IPs (elastic IPs) will be mapped to these IPs. So it is okay!

During the setup, you will be asked to either create a security key, or upload, or use existing. Whatever you choose, make sure you have the corresponding key (PEM file) in your computer, which you can use. Otherwise you will not be able to login to these instances. Worst case scenario, you may need to delete them (EC2 instance) and create them again.

Make sure you make the PEM file readable to only your user, like this:

```
[kamran@kworkhorse kamran]$ chmod 0400 /home/kamran/Downloads/Kubernetes-Cluster-on-Atomic-Oslo.pem


[kamran@kworkhorse kamran]$ ls /home/kamran/Downloads/Kubernetes-Cluster-on-Atomic-Oslo.pem -l
-r-------- 1 kamran kamran 1692 May  6 10:45 /home/kamran/Downloads/Kubernetes-Cluster-on-Atomic-Oslo.pem
[kamran@kworkhorse kamran]$ 
```

After the nodes becoe ready, you can manually assign them proper names, for better identification. Such as Kubernetes-Master , Kubernetes-Node-1 , etc. Remember, in our case we have one master and two worker nodes.

If you selected "No" to Auto Assign Public IPs either at the time of VPC creation or EC2 instances creation, then you should Allocate new public IPs and and Associate those public IPs to thesse instances.

It is also a good time to note the IP addresses in a text file somewhere on your computer, as you will be using them quite a lot throughout this lab.

My public/elastic IPs for this cluster are:

* Master: ec2-52-58-199-52.eu-central-1.compute.amazonaws.com   (IP of it's eth0: 10.0.0.135/24)
* Node-1: ec2-52-58-221-24.eu-central-1.compute.amazonaws.com   (IP of it's eth0: 10.0.0.136/24)
* Node-2: ec2-52-58-219-254.eu-central-1.compute.amazonaws.com  (IP of it's eth0: 10.0.0.137/24)


# Step 3: Update OS on all nodes:
Time to login to each/all EC2 instances of this cluster and update it's OS and reboot them all. 

For test setups, you should (read: must) disable SELinux - to save yourself from grief later. For production system, it depends on your comfort level with SELinux. (or, how brave you are! :) 

``` 
[kamran@kworkhorse kamran]$ ssh -i /home/kamran/Downloads/Kubernetes-Cluster-on-Atomic-Oslo.pem fedora@ec2-52-58-199-52.eu-central-1.compute.amazonaws.com
[fedora@ip-10-0-0-135 ~]$ 


[fedora@ip-10-0-0-135 ~]$ sudo atomic host upgrade ; sudo sed -i 's/=enforcing/=disabled/' /etc/selinux/config && sudo systemctl reboot
```

After the nodes have rebooted. Log in all of them, as we need to do Kubernetes setup on them. Just make sure if SELinux is disabled on all of them - for now.

```
[fedora@ip-10-0-0-137 ~]$ getenforce 
Disabled
[fedora@ip-10-0-0-137 ~]$ 
```

Note: By default the following services are already running on a freshly provisioned Atomic host. For now, most impostant are the docker and ssh services.

```
[fedora@ip-10-0-0-136 ~]$ systemctl | grep service | grep running
auditd.service                                                                            loaded active running   Security Auditing Service
crond.service                                                                             loaded active running   Command Scheduler
dbus.service                                                                              loaded active running   D-Bus System Message Bus
dm-event.service                                                                          loaded active running   Device-mapper event daemon
docker.service                                                                            loaded active running   Docker Application Container Engine
getty@tty1.service                                                                        loaded active running   Getty on tty1
gssproxy.service                                                                          loaded active running   GSSAPI Proxy Daemon
lvm2-lvmetad.service                                                                      loaded active running   LVM2 metadata daemon
NetworkManager.service                                                                    loaded active running   Network Manager
polkit.service                                                                            loaded active running   Authorization Manager
serial-getty@ttyS0.service                                                                loaded active running   Serial Getty on ttyS0
sshd.service                                                                              loaded active running   OpenSSH server daemon
systemd-journald.service                                                                  loaded active running   Journal Service
systemd-logind.service                                                                    loaded active running   Login Service
systemd-udevd.service                                                                     loaded active running   udev Kernel Device Manager
user@1000.service                                                                         loaded active running   User Manager for UID 1000
[fedora@ip-10-0-0-136 ~]$ 

```

# Step 4: Decide your overlay network:

Overlay network has the most important role in a Kubernetes network. There are many ways to do it, but the easiest is to do it with flannel [https://github.com/coreos/flannel](https://github.com/coreos/flannel) . Flannel is a virtual network that gives a subnet to each host for use with container runtimes.

The guide we are following, suggests 172.16.0.0/12 as an overlay network. You can use Subnet calculator to have an idea about the IP address ranges for overlay network. [http://www.subnet-calculator.com/cidr.php](http://www.subnet-calculator.com/cidr.php)

Note: It is also possible to increase the number of bits in the subnet mask of the overlay network. 

E.g. The overlay network 172.16.0.0/12 has the following qualities:

Net CIDR notation: 172.16.0.0/12
Mask bits: 12
CIDR Mask: 255.240.0.0
Maximum subnets: 1048576
Maximum addresses: 1048574
CIDR address range: 172.16.0.0 - 172.31.255.255


----
# Part 2: Setup master node
 
# Step 5: Create Local Docker Registry on Master:

From the guide:
> The Atomic cluster will use a local Docker registry mirror for caching with a local volume for persistence. You may need to look at the amount of storage available to the Docker storage pool on the master host. We don’t want the container recreated every time the service gets restarted, so we’ll create the container locally then set up a systemd unit file that will only start and stop the container.

> Create a named container from the Docker Hub registry image, exposing the standard Docker Hub port from the container via the host. We’re using a local host directory as a persistence layer for the images that get cached for use. The other environment variables passed in to the registry set the source registry.

Create the registry container:
```
[fedora@ip-10-0-0-135 ~]$ sudo docker create -p 5000:5000 \
>   -v /var/lib/local-registry:/var/lib/registry \
>   -e REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/var/lib/registry \
>   -e REGISTRY_PROXY_REMOTEURL=https://registry-1.docker.io \
>   --name=local-registry registry:2
Unable to find image 'registry:2' locally
Trying to pull repository docker.io/library/registry ... 2: Pulling from library/registry
3059b4820522: Pull complete 
ff978d850939: Pull complete 
5a85aa5e7c2b: Pull complete 
4fed082a39df: Pull complete 
bd6c2bfa3c21: Pull complete 
1f61fcdad08e: Pull complete 
a7eb18029047: Pull complete 
e79b1b77939a: Pull complete 
b0bfd772479f: Pull complete 
Digest: sha256:bf9b4a7b53a2f54c7b4d839103ca5be05b6a770ee0ba9c43e9ef23d602414f44
Status: Downloaded newer image for docker.io/registry:2

56cf6234d993ac0a2f2da0e39a8b620d15a6d3789dc3721dc4a154ac230f7470
[fedora@ip-10-0-0-135 ~]$ 
```

Since we want to make sure the local cache is always up, we’ll create a systemd unit file to start it and make sure it stays running. Reload the systemd daemon and start the new local-registry service.

```
[fedora@ip-10-0-0-135 ~]$ sudo vi /etc/systemd/system/local-registry.service

[Unit]
Description=Local Docker Mirror registry cache
Requires=docker.service
After=docker.service

[Service]
Restart=on-failure
RestartSec=10
ExecStart=/usr/bin/docker start -a %p
ExecStop=-/usr/bin/docker stop -t 2 %p

[Install]
WantedBy=multi-user.target

[fedora@ip-10-0-0-135 ~]$ sudo systemctl daemon-reload

[fedora@ip-10-0-0-135 ~]$ sudo systemctl enable local-registry
Created symlink from /etc/systemd/system/multi-user.target.wants/local-registry.service to /etc/systemd/system/local-registry.service.

[fedora@ip-10-0-0-135 ~]$ sudo systemctl start local-registry
```

# Step 6: Configure Kubernetes Master
## Confgure etcd:
We’re using a single etcd server, not a replicating cluster in this guide. This makes etcd simple, we just need to listen for client connections, then enable and start the daemon with all the rest of the Kubernetes services. For simplicity, we’ll have etcd listen on all IP addresses. The official port for etcd clients is 2379, but you can add add 4001 as well since that is widely used in many guides on the internet.

Edit etc.conf:
```
[fedora@ip-10-0-0-135 ~]$ sudo vi /etc/etcd/etcd.conf
ETCD_NAME=default
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"

```

## Configure Kubernetes common service configuration file:
```
[fedora@ip-10-0-0-135 ~]$ sudo vi /etc/kubernetes/config
KUBE_LOGTOSTDERR="--logtostderr=true"
KUBE_LOG_LEVEL="--v=0"
KUBE_ALLOW_PRIV="--allow-privileged=false"
KUBE_MASTER="--master=http://10.0.0.135:8080"
KUBE_ETCD_SERVERS="--etcd_servers=http://10.0.0.135:2379"
```

## Configure APIserver service:
```
[fedora@ip-10-0-0-135 ~]$ sudo vi /etc/kubernetes/apiserver
KUBE_API_ADDRESS="--insecure-bind-address=0.0.0.0"
KUBE_ETCD_SERVERS="--etcd-servers=http://127.0.0.1:2379"
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"
KUBE_ADMISSION_CONTROL="--admission-control=NamespaceLifecycle,NamespaceExists,LimitRanger,SecurityContextDeny,ResourceQuota"
KUBE_API_ARGS=""
```
**There are some points to note here:**
* On test clusters, you will need to remove ServiceAccount from the KUBE_ADMISSION_CONTROL parameter. The file shown above has that removed.
* If you need to modify the set of IPs that Kubernetes assigns to services, change the KUBE_SERVICE_ADDRESSES value. Since this guide is using the 10.0.0.0/16 (for VPC) , 10.0.0.0/24 (for public zone of VPC) and 172.16.0.0/12 (for flannel), we can safely use the default, which is 10.254.0.0/16 . This address space needs to be unused elsewhere, but doesn’t need to be reachable from either of the other networks. Note, this is **not** flannel. 

## Configure Controller-Manager and Scheduler:
There is no specific configuration to put in the config files of these two services. Leave them as it is and move on to next step.

# Step 7: Enable Kubernetes related services on master:

```
sudo systemctl enable etcd kube-apiserver kube-controller-manager kube-scheduler
sudo systemctl start etcd kube-apiserver kube-controller-manager kube-scheduler
```

```
[fedora@ip-10-0-0-135 ~]$ sudo systemctl enable etcd kube-apiserver kube-controller-manager kube-scheduler
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /usr/lib/systemd/system/etcd.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-apiserver.service to /usr/lib/systemd/system/kube-apiserver.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service to /usr/lib/systemd/system/kube-controller-manager.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-scheduler.service to /usr/lib/systemd/system/kube-scheduler.service.
[fedora@ip-10-0-0-135 ~]$ sudo systemctl start etcd kube-apiserver kube-controller-manager kube-scheduler
[fedora@ip-10-0-0-135 ~]$
```

Lets check the status of service before moving forward. Most important ones are: docker, etcd, kube-apiserver, kube-controller-manager and kube-scheduler .
```
[fedora@ip-10-0-0-135 ~]$ sudo systemctl | grep service | grep  running
auditd.service                                                                            loaded active running   Security Auditing Service
crond.service                                                                             loaded active running   Command Scheduler
dbus.service                                                                              loaded active running   D-Bus System Message Bus
dm-event.service                                                                          loaded active running   Device-mapper event daemon
docker.service                                                                            loaded active running   Docker Application Container Engine
etcd.service                                                                              loaded active running   Etcd Server
getty@tty1.service                                                                        loaded active running   Getty on tty1
gssproxy.service                                                                          loaded active running   GSSAPI Proxy Daemon
kube-apiserver.service                                                                    loaded active running   Kubernetes API Server
kube-controller-manager.service                                                           loaded active running   Kubernetes Controller Manager
kube-scheduler.service                                                                    loaded active running   Kubernetes Scheduler Plugin
local-registry.service                                                                    loaded active running   Local Docker Mirror registry cache
lvm2-lvmetad.service                                                                      loaded active running   LVM2 metadata daemon
NetworkManager.service                                                                    loaded active running   Network Manager
polkit.service                                                                            loaded active running   Authorization Manager
serial-getty@ttyS0.service                                                                loaded active running   Serial Getty on ttyS0
sshd.service                                                                              loaded active running   OpenSSH server daemon
systemd-journald.service                                                                  loaded active running   Journal Service
systemd-logind.service                                                                    loaded active running   Login Service
systemd-udevd.service                                                                     loaded active running   udev Kernel Device Manager
user@1000.service                                                                         loaded active running   User Manager for UID 1000
[fedora@ip-10-0-0-135 ~]$ 
```
Great!

# Step 8: Configure Flannel Overlay network on Master:
Flanneld provides a tunneled network configuration via etcd. To push the desired config into etcd, we’ll create a JSON file with the options we want and use curl to push the data into etcd. (That is why we need etcd in running state before we do this). We’ve selected a /12 network to create a /24 subnet per node.

```
[fedora@ip-10-0-0-135 ~]$ vi flanneld-conf.json
{
  "Network": "172.16.0.0/12",
  "SubnetLen": 24,
  "Backend": {
    "Type": "vxlan"
  }
}
[fedora@ip-10-0-0-135 ~]$ 
```

We’ll create a keyname specific to this cluster to store the network configuration. While we’re using a single etcd server in a single cluster for this example, setting non-overlapping keys allows us to have a multiple flannel configs for several Atomic clusters. Note that 'atomic01' in the command below is not name of a node. It is name of the key we are creating.

```
[fedora@ip-10-0-0-135 ~]$ curl -L http://localhost:2379/v2/keys/atomic01/network/config -XPUT --data-urlencode value@flanneld-conf.json

{"action":"set","node":{"key":"/atomic01/network/config","value":"{\n  \"Network\": \"172.16.0.0/12\",\n  \"SubnetLen\": 24,\n  \"Backend\": {\n    \"Type\": \"vxlan\"\n  }\n}\n","modifiedIndex":11,"createdIndex":11}}
[fedora@ip-10-0-0-135 ~]$ 
```

Just to make sure we have the right config, we’ll pull it via curl and parse the JSON return.

```
[fedora@ip-10-0-0-135 ~]$ curl -L --silent http://localhost:2379/v2/keys/atomic01/network/config | python -m json.tool

{
    "action": "get",
    "node": {
        "createdIndex": 11,
        "key": "/atomic01/network/config",
        "modifiedIndex": 11,
        "value": "{\n  \"Network\": \"172.16.0.0/12\",\n  \"SubnetLen\": 24,\n  \"Backend\": {\n    \"Type\": \"vxlan\"\n  }\n}\n"
    }
}
[fedora@ip-10-0-0-135 ~]$ 
```

We are good to go!

----
# Part 3: Setup worker nodes
We have already updated/prepared these nodes in the Part 1. Now we need to configure them.

# Step 9: Configuring Docker to use the cluster registry cache
All Worner nodes. Add the local cache registry (running on the master) to the docker options that get pulled into the systemd unit file on the nodes.

```
[fedora@ip-10-0-0-136 ~]$ sudo vi /etc/sysconfig/docker
OPTIONS='--registry-mirror=http://10.0.0.135:5000 --log-driver=journald'
DOCKER_CERT_PATH=/etc/docker
```
Repeat on node 2.

# Step 10: Configuring Docker to use the Flannel overlay

To set up flanneld, we need to tell the local flannel service where to find the etcd service serving up the config. We also give it the right key to find the networking values for this cluster.

All Worker nodes:
```
[fedora@ip-10-0-0-136 ~]$  sudo vi /etc/sysconfig/flanneld
FLANNEL_ETCD="http://10.0.0.135:2379"
FLANNEL_ETCD_KEY="/atomic01/network"
```

**NOTE:** There is no need to have a trailing '/config' in the line FLANNEL_ETCD_KEY . If you do that, flannel and docker will fail to work.

Repeat on node 2.


To get docker using the flanneld overlay, we’ll change the networking config to use the flanneld provided bridge IP and MTU settings. We’ll also change the unit definition to wait for flanneld to start. That way the environment file created by flanneld is available and will provide a usable address for the docker0 bridge.

Using a systemd drop-in file allows us to override the distributed systemd unit file without making direct modifications. The blank ExecStart= line erases all previously defined ExecStart directives and only subsequent ExecStart lines will be used by systemd.

All worker nodes:
```
[fedora@ip-10-0-0-136 ~]$ sudo mkdir -p /etc/systemd/system/docker.service.d/


[fedora@ip-10-0-0-136 ~]$ sudo vi /etc/systemd/system/docker.service.d/10-flanneld-network.conf
[Unit]
After=flanneld.service
Requires=flanneld.service

[Service]
EnvironmentFile=/run/flannel/subnet.env
ExecStartPre=-/usr/sbin/ip link del docker0
ExecStart=
ExecStart=/usr/bin/docker -d \
      --bip=${FLANNEL_SUBNET} \
      --mtu=${FLANNEL_MTU} \
      $OPTIONS \
      $DOCKER_STORAGE_OPTIONS \
      $DOCKER_NETWORK_OPTIONS \
      $INSECURE_REGISTRY
```
Repeat on node 2.

# Step 11: Configure the Kubelet service on worker nodes
The address entry in the kubelet config file must match the KUBLET_ADDRESSES entry on the master. If hostnames are used, this also must match output of hostname -f on the node. We’re using the eth0 IP address like we did on the master.

All nodes:
```
[fedora@ip-10-0-0-137 ~]$ sudo vi /etc/kubernetes/kubelet

KUBELET_ADDRESS="--address=10.0.0.136"
KUBELET_HOSTNAME="--hostname-override=10.0.0.136"
KUBELET_API_SERVER="--api-servers=http://10.0.0.135:8080"
KUBELET_ARGS=""
```
Repeat on node 2.

# Step 12: Configure the general Kubernetes config file
Set the location of the etcd server.
All nodes:
```
[fedora@ip-10-0-0-136 ~]$ sudo vi /etc/kubernetes/config 

KUBE_LOGTOSTDERR="--logtostderr=true"
KUBE_LOG_LEVEL="--v=0"
KUBE_ALLOW_PRIV="--allow-privileged=false"
KUBE_MASTER="--master=http://10.0.0.135:8080"
```
Repeat on node 2.

# Step 13: Reload node services, Reboot nodes and check status of services
Reload systemd and then enable the node services. Reboot the node to make sure everything starts on boot correctly.

All nodes:
```
[fedora@ip-10-0-0-136 ~]$ sudo systemctl daemon-reload
[fedora@ip-10-0-0-136 ~]$ sudo systemctl enable flanneld kubelet kube-proxy
Created symlink from /etc/systemd/system/multi-user.target.wants/flanneld.service to /usr/lib/systemd/system/flanneld.service.
Created symlink from /etc/systemd/system/docker.service.requires/flanneld.service to /usr/lib/systemd/system/flanneld.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /usr/lib/systemd/system/kubelet.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-proxy.service to /usr/lib/systemd/system/kube-proxy.service.
[fedora@ip-10-0-0-136 ~]$ 

[fedora@ip-10-0-0-136 ~]$ sudo systemctl reboot

```

Repeat on node 2.

## Check services' health after reboot on worker nodes:
All worker nodes:
```
sudo systemctl status flanneld docker kubelet kube-proxy
```
You should see all Green (dots)!; services loaded and running.


At this point, if you see your services "Loaded" but "Inactive (dead)", then there may be problem with your firewall rules in the AWS security group. (This is almost always the cause!). Since this is a test cluster, you can set the security to "Allow All Traffic from 0.0.0.0/0" . (We want this to work right?) You can tighten the security rules later. Restart services or reboot worker nodes after you fix the security group.

All worker nodes. Make sure flanneld, docker, kubelet and kube-proxy are running.
```
[fedora@ip-10-0-0-136 ~]$ systemctl | grep service| grep running
auditd.service                                                                            loaded active running   Security Auditing Service
crond.service                                                                             loaded active running   Command Scheduler
dbus.service                                                                              loaded active running   D-Bus System Message Bus
dm-event.service                                                                          loaded active running   Device-mapper event daemon
docker.service                                                                            loaded active running   Docker Application Container Engine
flanneld.service                                                                          loaded active running   Flanneld overlay address etcd agent
getty@tty1.service                                                                        loaded active running   Getty on tty1
gssproxy.service                                                                          loaded active running   GSSAPI Proxy Daemon
kube-proxy.service                                                                        loaded active running   Kubernetes Kube-Proxy Server
kubelet.service                                                                           loaded active running   Kubernetes Kubelet Server
lvm2-lvmetad.service                                                                      loaded active running   LVM2 metadata daemon
NetworkManager.service                                                                    loaded active running   Network Manager
polkit.service                                                                            loaded active running   Authorization Manager
serial-getty@ttyS0.service                                                                loaded active running   Serial Getty on ttyS0
sshd.service                                                                              loaded active running   OpenSSH server daemon
systemd-journald.service                                                                  loaded active running   Journal Service
systemd-logind.service                                                                    loaded active running   Login Service
systemd-udevd.service                                                                     loaded active running   udev Kernel Device Manager
user@1000.service                                                                         loaded active running   User Manager for UID 1000
[fedora@ip-10-0-0-136 ~]$ 
```
Repeat on node2.

## Check network configuration on both worker nodes:

**Node 1:**
```
[fedora@ip-10-0-0-136 ~]$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 02:56:fc:b0:cd:91 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.136/24 brd 10.0.0.255 scope global dynamic eth0
       valid_lft 2417sec preferred_lft 2417sec
    inet6 fe80::56:fcff:feb0:cd91/64 scope link 
       valid_lft forever preferred_lft forever
3: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether ee:4b:88:fa:2e:7d brd ff:ff:ff:ff:ff:ff
    inet 172.16.78.0/12 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::ec4b:88ff:fefa:2e7d/64 scope link 
       valid_lft forever preferred_lft forever
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:07:0b:73:47 brd ff:ff:ff:ff:ff:ff
    inet 172.16.78.1/24 scope global docker0
       valid_lft forever preferred_lft forever
[fedora@ip-10-0-0-136 ~]$ 


[fedora@ip-10-0-0-136 ~]$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.0.1        0.0.0.0         UG    100    0        0 eth0
10.0.0.0        0.0.0.0         255.255.255.0   U     100    0        0 eth0
172.16.0.0      0.0.0.0         255.240.0.0     U     0      0        0 flannel.1
172.16.78.0     0.0.0.0         255.255.255.0   U     0      0        0 docker0
[fedora@ip-10-0-0-136 ~]$ 
```


**Node 2:**
```
[fedora@ip-10-0-0-137 ~]$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 02:98:f7:8f:ba:a7 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.137/24 brd 10.0.0.255 scope global dynamic eth0
       valid_lft 3378sec preferred_lft 3378sec
    inet6 fe80::98:f7ff:fe8f:baa7/64 scope link 
       valid_lft forever preferred_lft forever
3: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 8951 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 4e:44:91:08:f6:a2 brd ff:ff:ff:ff:ff:ff
    inet 172.16.20.0/12 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::4c44:91ff:fe08:f6a2/64 scope link 
       valid_lft forever preferred_lft forever
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:39:ac:dd:41 brd ff:ff:ff:ff:ff:ff
    inet 172.16.20.1/24 scope global docker0
       valid_lft forever preferred_lft forever
[fedora@ip-10-0-0-137 ~]$


[fedora@ip-10-0-0-137 ~]$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.0.1        0.0.0.0         UG    100    0        0 eth0
10.0.0.0        0.0.0.0         255.255.255.0   U     100    0        0 eth0
172.16.0.0      0.0.0.0         255.240.0.0     U     0      0        0 flannel.1
172.16.20.0     0.0.0.0         255.255.255.0   U     0      0        0 docker0
[fedora@ip-10-0-0-137 ~]$ 
```


## Check networking on Master node:
```
[fedora@ip-10-0-0-135 ~]$ ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 02:17:1c:af:78:b7 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.135/24 brd 10.0.0.255 scope global dynamic eth0
       valid_lft 2426sec preferred_lft 2426sec
    inet6 fe80::17:1cff:feaf:78b7/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue state UP group default 
    link/ether 02:42:0b:2d:cb:2e brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
    inet6 fe80::42:bff:fe2d:cb2e/64 scope link 
       valid_lft forever preferred_lft forever
5: vethe4ac63c@if4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc noqueue master docker0 state UP group default 
    link/ether c2:b9:8c:2c:c9:64 brd ff:ff:ff:ff:ff:ff link-netnsid 0
[fedora@ip-10-0-0-135 ~]$ 


[fedora@ip-10-0-0-135 ~]$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.0.1        0.0.0.0         UG    100    0        0 eth0
10.0.0.0        0.0.0.0         255.255.255.0   U     100    0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
[fedora@ip-10-0-0-135 ~]$ 
```

## Check if master can see the nodes:
If all is configured correctly, i.e. communications are setup correctly, then master should see the nodes through kubectl command.

On Master node, ping nodes:
```
[fedora@ip-10-0-0-135 ~]$ ping -c2 10.0.0.136
PING 10.0.0.136 (10.0.0.136) 56(84) bytes of data.
64 bytes from 10.0.0.136: icmp_seq=1 ttl=64 time=0.373 ms
64 bytes from 10.0.0.136: icmp_seq=2 ttl=64 time=0.457 ms

--- 10.0.0.136 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1000ms
rtt min/avg/max/mdev = 0.373/0.415/0.457/0.042 ms


[fedora@ip-10-0-0-135 ~]$ ping -c2 10.0.0.137
PING 10.0.0.137 (10.0.0.137) 56(84) bytes of data.
64 bytes from 10.0.0.137: icmp_seq=1 ttl=64 time=0.357 ms
64 bytes from 10.0.0.137: icmp_seq=2 ttl=64 time=0.360 ms

--- 10.0.0.137 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 999ms
rtt min/avg/max/mdev = 0.357/0.358/0.360/0.019 ms
[fedora@ip-10-0-0-135 ~]$ 
```

On master node, check if Kubernetes can see nodes:
```
[fedora@ip-10-0-0-135 ~]$ kubectl get nodes
NAME         STATUS    AGE
10.0.0.136   Ready     15m
10.0.0.137   Ready     6m
[fedora@ip-10-0-0-135 ~]$
```

Hurray! The cluster is setup correctly. We can now start using it!

----
# Part 4: Using the cluster






