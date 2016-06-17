# # Using Vagrant + Libvirt to setup a Kubernetes cluster (Part-2)

# First check and fix DNS

Name resolution from busybox takes for ever and does not resolve yahoo.com nor any kubernetes service. Master and worker nodes were rebooted, still no effect. A little more dig down:

```
[vagrant@kubernetes-master ~]$ kubectl --namespace=kube-system exec -it kube-dns-v11-uzgn2 -c skydns -- sh
/ # cat /etc/resolv.conf 
nameserver 192.168.121.1
options ndots:5


/ # nslookup yahoo.com
Server:    192.168.121.1
Address 1: 192.168.121.1

Name:      yahoo.com
Address 1: 98.139.183.24 ir2.fp.vip.bf1.yahoo.com
Address 2: 206.190.36.45 ir1.fp.vip.gq1.yahoo.com
Address 3: 98.138.253.109 ir1.fp.vip.ne1.yahoo.com

/ # nslookup kubernetes
Server:    192.168.121.1
Address 1: 192.168.121.1

nslookup: can't resolve 'kubernetes'

/ # nslookup kubernetes.default.svc.cluster.local
Server:    192.168.121.1
Address 1: 192.168.121.1

nslookup: can't resolve 'kubernetes.default.svc.cluster.local'
```

So, I manually added the kubernetes service address to skyDNS's resolv.conf:

```
/ # vi /etc/resolv.conf 
nameserver 10.247.0.10
nameserver 192.168.121.1
options ndots:5


/ # nslookup kubernetes.default.svc.cluster.local
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes.default.svc.cluster.local
Address 1: 10.247.0.1
/ # exit
[vagrant@kubernetes-master ~]$ 
```

It works at least locally!

Lets check from a busybox pod.


```
[vagrant@kubernetes-master ~]$ kubectl exec -it busybox --  sh
/ # nslookup yahoo.com
Server:    10.247.0.10
Address 1: 10.247.0.10

nslookup: can't resolve 'yahoo.com'
/ # nslookup kubernetes
Server:    10.247.0.10
Address 1: 10.247.0.10

nslookup: can't resolve 'kubernetes'
/ # exiterror: error executing remote command: Error executing command in container: Error executing in Docker Container: 1
[vagrant@kubernetes-master ~]$ 
```

This is the same ***** problem :( I thought that setting up the kubernetes cluster using the kubernetes script will help solve this. It did not!

Need to raise a issue on kubernetes github repo.


