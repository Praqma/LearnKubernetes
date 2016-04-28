# Kubernetes on Fedora - Multi node

References:
* http://kubernetes.io/docs/getting-started-guides/fedora/fedora_manual_config/
* http://kubernetes.io/docs/getting-started-guides/fedora/flannel_multi_node_cluster/


## Host setup:
Two nodes on Local computer (KVM) . Amazon does not have images for Fedora. (It does have images for REH 7 though)

fed-master: 192.168.124.50


## Package installation:

The Kubernetes package provides a few services: 
* kube-apiserver, 
* kube-scheduler, 
* kube-controller-manager, 
* kubelet, 
* kube-proxy. 

These services are managed by systemd and the configuration resides in a central location: /etc/kubernetes. 

We will break the services up between the hosts. 

The first host, fed-master, will be the Kubernetes master, and will run the following:
* kube-apiserver, 
* kube-controller-manager
* kube-scheduler. 
* etcd

Note: etcd can run on a different host but this guide assumes that etcd and Kubernetes master run on the same host. 

The remaining host, fed-node will be the node and run the following: 
* kubelet, 
* proxy 
* docker.


At the moment I am using Fedora 23. I see that Fedora standard repository has kubernetes, and the update-testing repo has a little newer version of kubernetes, as shown below. I will try to use the stable version from the "updates" repository:

```bash
[root@fed-master ~]# yum list kubernetes

Last metadata expiration check performed 0:05:01 ago on Thu Apr 28 12:07:32 2016.
Available Packages
kubernetes.x86_64                                           1.2.0-0.15.alpha6.gitf0cd09a.fc23                                            updates
[root@fed-master ~]# yum list  --enablerepo=updates-testing kubernetes

Last metadata expiration check performed 0:00:01 ago on Thu Apr 28 12:12:55 2016.
Available Packages
kubernetes.x86_64                                           1.2.0-0.18.git4a3f9c5.fc23                                           updates-testing
[root@fed-master ~]# 
``` 

Same goes for etcd:

```
[root@fed-master ~]# yum list etcd
Yum command has been deprecated, redirecting to '/usr/bin/dnf list etcd'.
See 'man dnf' and 'man yum2dnf' for more information.
To transfer transaction metadata from yum to DNF, run:
'dnf install python-dnf-plugins-extras-migrate && dnf-2 migrate'

Last metadata expiration check performed 0:08:22 ago on Thu Apr 28 12:07:32 2016.
Available Packages
etcd.x86_64                                                         2.2.5-1.fc23                                                         updates
[root@fed-master ~]# 
```




### Install **kubernetes**, **etcd** and **iptables** on the master node **fed-master**:

```
[root@fed-master ~]# yum install kubernetes  etcd iptables 
Dependencies resolved.
================================================================================================================================================
 Package                            Arch                    Version                                              Repository                Size
================================================================================================================================================
Installing:
 etcd                               x86_64                  2.2.5-1.fc23                                         updates                  5.9 M
 kubernetes                         x86_64                  1.2.0-0.15.alpha6.gitf0cd09a.fc23                    updates                   39 k
 kubernetes-client                  x86_64                  1.2.0-0.15.alpha6.gitf0cd09a.fc23                    updates                  8.8 M
 kubernetes-master                  x86_64                  1.2.0-0.15.alpha6.gitf0cd09a.fc23                    updates                   15 M
 kubernetes-node                    x86_64                  1.2.0-0.15.alpha6.gitf0cd09a.fc23                    updates                  8.7 M
 socat                              x86_64                  1.7.2.4-5.fc23                                       fedora                   276 k

Transaction Summary
================================================================================================================================================
Install  6 Packages

Total download size: 39 M
Installed size: 192 M
. . . 
``` 


