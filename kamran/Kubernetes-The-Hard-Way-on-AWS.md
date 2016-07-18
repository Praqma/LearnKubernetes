# Kubernetes - The hard way - on AWS

# Summary
This document is an attempt to create a Kubernetes cluster, the same way as one would build on GCE. You can check this document here: [Kubernetes-The-Hard-Way-on-GCE.md](Kubernetes-The-Hard-Way-on-GCE.md) , if you want a reference.

The idea is to also include a LoadBalancer which we (Praqma) built especially for Kubernetes. I will also try to setup an internal load balancer for Kubernetes Master/Controller nodes, something which I did not do (nor Kelsey did) while setting up Kubernetes on GCE.

This setup will also introduce High Availability for etcd and master/controller nodes.

# Network setup

I have created a new VPC on AWS with a base network address of 10.0.0.0/16 .
This VPC has a public subnet inside it with a network address of 10.0.0.0/24 . All the nodes are created in this (so called - public) network.

There are 6 nodes in total for main Kubernetes functionality, with the following IP addresses:

* etcd1 - 54.93.98.33 - 10.0.0.245
* etcd2 - 54.93.95.206 - 10.0.0.246
* controller1 - 54.93.35.52 - 10.0.0.137
* controller2 - 54.93.88.77 - 10.0.0.138
* worker1 - 52.59.249.129 - 10.0.0.181
* worker2 - 54.93.34.227 - 10.0.0.182


I will use the same /etc/hosts on all nodes, so I do not have to keep track of the IP addresses in various config files.

The /etc/hosts file I will use is:
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
10.0.0.245	etcd1
10.0.0.246	etcd2
10.0.0.137	controller1
10.0.0.138	controller2
10.0.0.181	worker1
10.0.0.182	worker2
```





