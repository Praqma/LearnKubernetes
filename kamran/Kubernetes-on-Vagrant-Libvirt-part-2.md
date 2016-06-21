# Using Vagrant + Libvirt to setup a Kubernetes cluster (Part-2)

# First check and fix DNS

I noticed that Kubernetes DNS is one service, which is **not** documented well - at all! This happens when a project is new, and is moving fast!

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

Important log files are in /var/log of master node and on worker nodes :

Master:
```
[vagrant@kubernetes-master ~]$ ls /var/log/kube-* -1
/var/log/kube-apiserver.log
/var/log/kube-controller-manager.log
/var/log/kube-scheduler.log

[vagrant@kubernetes-master ~]$ ls /var/log/etcd* -1
/var/log/etcd-events.log
/var/log/etcd.log
[vagrant@kubernetes-master ~]$ 
```


Worker Node:
(I could not find the log for kubelet on the worker node  - which is very strange!).
```
[vagrant@kubernetes-node-1 ~]$ ls /var/log/kube-proxy.log -1
/var/log/kube-proxy.log
[vagrant@kubernetes-node-1 ~]$ 
```

That is not all though! The next time I rebooted nodes, it again went bad and nslookup from busybox pod took forever before failing.


I sensed that busybox is not being very helpful in debugging DNS issues. So I decided to create a centos pod. I created the following pod definition, created/started it, and then, installed bind-utils in it with yum. I was getting the nameserver set as 10.247.0.10 in it's resolv.conf (when it was created), but since DNS was not working, yum did not work, and I had to change the DNS in centos resolv.conf to 192.168.121.1 (manually - by logging into the pod , in interactive mode). Here is the centos.yaml file:

```
[root@kworkhorse kamran]# cat centos.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: centos
  namespace: default
spec:
  containers:
  - image: centos
    command:
      - sleep
      - "3600"
    imagePullPolicy: IfNotPresent
    name: centos
  restartPolicy: Always
[root@kworkhorse kamran]# 
```

Once I used this pod (and dig) to query about the service "kubernetes", here is what I got:

```
[root@kworkhorse kamran]# kubectl exec centos -it -- bash
[root@centos /]# 

[root@centos /]# dig kubernetes @10.247.0.10
;; reply from unexpected source: 10.246.92.5#53, expected 10.247.0.10#53
;; reply from unexpected source: 10.246.92.5#53, expected 10.247.0.10#53
;; reply from unexpected source: 10.246.92.5#53, expected 10.247.0.10#53

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> kubernetes @10.247.0.10
;; global options: +cmd
;; connection timed out; no servers could be reached
[root@centos /]#
```
Notice the strange (failure) reply is coming from 10.246.92.5 (some pod IP from flannel network segment on node-1), and not from 10.247.0.10 ! It looks like some IPTable rules might be messed up on the worker node! 


I restarted kubelet service on worker node.
```
[vagrant@kubernetes-node-1 ~]$ sudo systemctl restart kubelet.service
```

, and tried again:

```
[root@centos /]# dig kubernetes @10.247.0.10

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> kubernetes @10.247.0.10
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: SERVFAIL, id: 54087
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;kubernetes.			IN	A

;; Query time: 1 msec
;; SERVER: 10.247.0.10#53(10.247.0.10)
;; WHEN: Sun Jun 19 13:35:02 UTC 2016
;; MSG SIZE  rcvd: 28

[root@centos /]# 
```

Hmmm! Interesting! At least DNS is reachable now! Resolving yahoo seems to work!

```
[root@centos /]# dig yahoo.com @10.247.0.10 

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> yahoo.com @10.247.0.10
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 47453
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1280
;; QUESTION SECTION:
;yahoo.com.			IN	A

;; ANSWER SECTION:
yahoo.com.		133	IN	A	98.138.253.109
yahoo.com.		133	IN	A	206.190.36.45
yahoo.com.		133	IN	A	98.139.183.24

;; Query time: 7 msec
;; SERVER: 10.247.0.10#53(10.247.0.10)
;; WHEN: Sun Jun 19 13:35:10 UTC 2016
;; MSG SIZE  rcvd: 86

[root@centos /]# 
```

I checked my resolv.conf on centos pod and saw that I have disabled the search directive. So DNS cannot resolve "kubernetes" because it does not know the domain suffix to try.

```
[root@centos /]# cat /etc/resolv.conf 
# search default.svc.cluster.local svc.cluster.local cluster.local
nameserver 10.247.0.10
nameserver 192.168.121.1
# options ndots:5
[root@centos /]#
```

So it works when I try FQDN for kubernetes:
```

[root@centos /]# dig kubernetes.default.svc.cluster.local @10.247.0.10

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> kubernetes.default.svc.cluster.local @10.247.0.10
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 22574
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;kubernetes.default.svc.cluster.local. IN A

;; ANSWER SECTION:
kubernetes.default.svc.cluster.local. 30 IN A	10.247.0.1

;; Query time: 1 msec
;; SERVER: 10.247.0.10#53(10.247.0.10)
;; WHEN: Sun Jun 19 13:35:31 UTC 2016
;; MSG SIZE  rcvd: 70

[root@centos /]#
```

And just for record, here is the final version of resolv.conf from the skydns container:

```
[root@kworkhorse kamran]# kubectl --namespace=kube-system exec kube-dns-v11-auj3o -c skydns -it -- sh 
/ # cat /etc/resolv.conf 
nameserver 127.0.0.1
nameserver 192.168.121.1
options ndots:5
/ # 
```


This is a weird solution. I mean, do I have to restart kubelet service on nodes after I am done setting up a service?

