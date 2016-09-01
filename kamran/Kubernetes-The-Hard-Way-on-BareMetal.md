# Kubernetes The Hard Way - Bare Metal

This document is going to be the last document in the series of Kubernetes the Hard Way. It follows Kelsey Hightower's turtorial [https://github.com/kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) , and attempts to make improvements and explanations where needed. So here we go.

# Target Audience
The target audience for this tutorial is someone planning to setup or support a production Kubernetes cluster and wants to understand how everything fits together. 

# Infrastructure:
I do not have actual bare metal. I have vitual machines, running on LibVirt/KVM on my work computer (Fedora 23 - 64 bit). Some may argue that I could have used Amazon AWS, and used VMs over there too. Well, I tried that , documented here: [Kubernetes-The-Hard-Way-on-AWS.md](Kubernetes-The-Hard-Way-on-AWS.md) , and it did not work when I reached Pod Networking on worker nodes. Amazon has it's VPC mechanism, and it did not let the traffic flow between two pod networks on two different worker nodes. May be I did not know how to get that done correctly, but this type of routing on AWS VPC is not documented either. So I had to abandon it. 


So, I am going to use VMs on my work computer to create this setup. But before I start building VMs, I want to mention few important things.

## Networking:
Kubernetes uses three different types of networks. They are:

* Infrastructure Network: The network your physical (or virtual) machines are connected to. Normally your production network, or a part of it.
* Service Network: The (completely) virtual (rather fictional) network, which is used to assign IP addresses to Kubernetes Services, which you will be creating. (A Service is a frontend to a RC or a Deployment). It must be noted that IP from this network are **never** assigned to any of the interfaces of any of the nodes/VMs, etc. These (Service IPs) are used behind the scenes by kube-proxy to create (weird) iptables rules on the worker nodes. 
* Pod Network: This is the network, which is used by the pods. However it is not a simple network either, depending on what kubernetes network solution you are employing. If you are using flannel, then this would be a large software defined overlay network, and each worker node will get a subnet of this network and configured for it's docker0 interface (in very simple words, there is a little more to it). If you are employing CIDR network, using CNI, then it would be a large network called **cluster-cidr** , with small subnets corresponding to your worker nodes. The routing table of the router handling your part of infrastructure network will need to be updated with routes to these small subnets. This proved to be a challenge on AWS VPC router, but this is piece of cake on a simple/generic router in your network. I will be doing it on my work computer, and setting up routes on Linux is a very simple task.

Kelsey used the following three networks in his guide, and I intend to use the same ones, so people following this guide, but checking his guide for reference are not confused in different IP schemes. So here are my three networks , which I will use for this guide.

* Infrastructure network:     10.240.0.0/24 
* Service Network:            10.32.0.0/24 
* Pod Network (Cluster CIDR): 10.200.0.0/16 


By default I have a virtual network 192.168.124.0/24 configured on my work computer, provided by libvirt. However, I want to be as close to Kelsey's guide as possible, so my infrastructure network is going to be 10.240.0.0/24 . I will just create a new virtual network (10.240.0.0/24) on my work computer.


## DNS names:
It is understood that all nodes in this cluster will have some hostname assigned to them. It is important to have consistent hostnames, and if there is a DNS server in your infrastructure, then it is also important what are the reverse lookup names of these nodes. This information is  critical at the time when you will generate SSL certificates. 


## Operating System:
Fedora 24 64 bit server edition - on all nodes. Even though I wanted to use Fedora Atomic, I am not using that. It is because Fedora Atomic is a collection of binaries bundled together (in a read only  filesystem), and individual packages cannot be updated. There is no yum, etc. I am going to use latest version of Kubernetes 1.3, which is still not part of Fedora Atomic. 

# Expectations

A working kubernetes cluster with:
* 2 x etcd nodes (in H/A configuration) 
* 2 x Kubernetes controller nodes (in H/A configuration) 
* 2 x Kubernetes worker nodes
* SSL based communication between all Kubernetes components
* Internal Cluster DNS (SkyDNS) - as cluster addon
* Default Service accounts and Secrets


# Supporting software needed for this setup:
* Kubernetes - 1.3.0 or later (Download latest from Kubernetes website)
* etcd - 2.2.5 or later (The one that comes with Fedora is good enough)
* Docker - 1.11.2 or later (Download latest from Docker website)
* CNI networking [https://github.com/containernetworking/cni](https://github.com/containernetworking/cni)


