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

This is the same silly problem :( I thought that setting up the kubernetes cluster using the kubernetes script will help solve this. It did not!

Need to raise a issue on kubernetes github repo.

----

Woke up next morning, brought my computer back from hybernation, re-ran the command with busybox, and this time it seems to work! This is unpridicted behavior. 

```
[root@kworkhorse kamran]# kubectl exec busybox -- nslookup kubernetes
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes
Address 1: 10.247.0.1
[root@kworkhorse kamran]# kubectl exec busybox -- nslookup kubernetes
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes
Address 1: 10.247.0.1
[root@kworkhorse kamran]# kubectl exec busybox -- nslookup kubernetes.default
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes.default
Address 1: 10.247.0.1
[root@kworkhorse kamran]# 
```

```
[vagrant@kubernetes-master ~]$ kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
[vagrant@kubernetes-master ~]$ kubectl exec busybox -- nslookup kubernetes
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes
Address 1: 10.247.0.1
[vagrant@kubernetes-master ~]$ kubectl exec busybox -- nslookup kubernetes.default
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes.default
Address 1: 10.247.0.1
[vagrant@kubernetes-master ~]$ kubectl exec busybox -- nslookup kubernetes.default.svc 
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes.default.svc
Address 1: 10.247.0.1
[vagrant@kubernetes-master ~]$ kubectl exec busybox -- nslookup kubernetes.default.svc.cluster.local 
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      kubernetes.default.svc.cluster.local
Address 1: 10.247.0.1
[vagrant@kubernetes-master ~]$ kubectl exec busybox -- nslookup yahoo.com
Server:    10.247.0.10
Address 1: 10.247.0.10

Name:      yahoo.com
Address 1: 2001:4998:c:a06::2:4008 ir1.fp.vip.gq1.yahoo.com
Address 2: 2001:4998:44:204::a7 ir1.fp.vip.ne1.yahoo.com
Address 3: 2001:4998:58:c02::a9 ir1.fp.vip.bf1.yahoo.com
Address 4: 98.139.183.24 ir2.fp.vip.bf1.yahoo.com
Address 5: 206.190.36.45 ir1.fp.vip.gq1.yahoo.com
Address 6: 98.138.253.109 ir1.fp.vip.ne1.yahoo.com
[vagrant@kubernetes-master ~]$ 
```

Trying to dig deeper into logs and all that, but kubernetes log system is very confusing. After spending several hours, I could not put my finger on a specific reason that cause it to fail, or to work. This needs more investigation.






