# Configure SkyDNS in the cluster

**Note: I separated this from the main document, because troubleshooting it was a long process and I wanted to document that too.**


Reference: [https://github.com/kubernetes/kubernetes/blob/release-1.2/cluster/addons/dns/README.md#how-do-i-configure-it](https://github.com/kubernetes/kubernetes/blob/release-1.2/cluster/addons/dns/README.md#how-do-i-configure-it)

You will need to modify the kubelet config on each node to add the cluster DNS settings and restart before setting up any of your pods/deployments/services.

The easiest way to use DNS is to use a supported kubernetes cluster setup, which should have the required logic to read some config variables and plumb them all the way down to kubelet.

Supported environments offer the following config flags, which are used at cluster turn-up to create the SkyDNS pods and configure the kubelets. For example, see cluster/gce/config-default.sh.

```
ENABLE_CLUSTER_DNS="${KUBE_ENABLE_CLUSTER_DNS:-true}"
DNS_SERVER_IP="10.254.0.10"
DNS_DOMAIN="cluster.local"
DNS_REPLICAS=1
``` 

Note: Our ServiceAddresses are in the range 10.254.0.0/16 . So I changed the IP of the DNS from 10.0.0.10 (from example) to 10.254.0.10 to use in this cluster.

This enables DNS with a DNS Service IP of 10.254.0.10 and a local domain of cluster.local, served by a single copy of SkyDNS.

If you are not using a supported cluster setup, you will have to replicate some of this yourself. First, each kubelet needs to run with the following flags set (in config file):

```
--cluster-dns=<DNS service ip>
--cluster-domain=<default local domain>
```

Second, you need to start the DNS server ReplicationController and Service. 

We will use the example files (ReplicationController and Service), but keep in mind that these are templated for Salt. You will need to replace the {{ <param> }} blocks with your own values for the config variables mentioned above. Other than the templating, these are normal kubernetes objects, and can be instantiated with kubectl create.

Try not to mess with apiversion v1 and the kind ReplicationContoller. I tried to convert it to a Deployment, but did not success. This needs to be attended in future.

Also, May be we can change the namespace from kube-system to default. It is very easy to forget to include all namespaces in the kubectl commands and then panicing! 

```
[fedora@kube-master ~]$ cat skydns-rc.yaml 
apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-dns-v11
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    version: v11
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: kube-dns
    version: v11
  template:
    metadata:
      labels:
        k8s-app: kube-dns
        version: v11
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - name: etcd
        image: gcr.io/google_containers/etcd-amd64:2.2.1
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            cpu: 100m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 50Mi
        command:
        - /usr/local/bin/etcd
        - -data-dir
        - /var/etcd/data
        - -listen-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -advertise-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -initial-cluster-token
        - skydns-etcd
        volumeMounts:
        - name: etcd-storage
          mountPath: /var/etcd/data
      - name: kube2sky
        image: gcr.io/google_containers/kube2sky:1.14
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            cpu: 100m
            # Kube2sky watches all pods.
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          # we poll on pod startup for the Kubernetes master service and
          # only setup the /readiness HTTP server once that's available.
          initialDelaySeconds: 30
          timeoutSeconds: 5
        args:
        # command = "/kube2sky"
        - --domain= "cluster.local"
      - name: skydns
        image: gcr.io/google_containers/skydns:2015-10-13-8c72f8c
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        args:
        # command = "/skydns"
        - -machines=http://127.0.0.1:4001
        - -addr=0.0.0.0:53
        - -ns-rotate=false
        - -domain="cluster.local."
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
      - name: healthz
        image: gcr.io/google_containers/exechealthz:1.0
        resources:
          # keep request = limit to keep this container in guaranteed class
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
        args:
        - -cmd=nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
        - -port=8080
        ports:
        - containerPort: 8080
          protocol: TCP
      volumes:
      - name: etcd-storage
        emptyDir: {}
      dnsPolicy: Default  # Don't use cluster DNS.
[fedora@kube-master ~]$ 
```

```
[fedora@kube-master ~]$ cat skydns-svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP:  10.254.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
[fedora@kube-master ~]$ 
```

Now create the SkyDNS ReplicationController and Service. 

```
[fedora@kube-master ~]$ kubectl create -f ./skydns-rc.yaml 
replicationcontroller "kube-dns-v11" created
[fedora@kube-master ~]$

[fedora@kube-master ~]$ kubectl get rc --namespace=kube-system
NAME           DESIRED   CURRENT   AGE
kube-dns-v11   1         1         28s
[fedora@kube-master ~]$ 



```


```
[fedora@kube-master ~]$ kubectl get pods --namespace=kube-system
NAME                        READY     STATUS    RESTARTS   AGE
kube-dns-v11-8k61o          3/4       Running   1          2m
[fedora@kube-master ~]$ 
```

Create the service fr skyDNS:

```
[fedora@kube-master ~]$ kubectl create -f ./skydns-svc.yaml 
service "kube-dns" created
[fedora@kube-master ~]$ 
``` 

```
[fedora@kube-master ~]$ kubectl get service  --namespace=kube-system
NAME         CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
kube-dns     10.254.0.10     <none>        53/UDP,53/TCP   4s
[fedora@kube-master ~]$ 
```


Alternate way (from CoreOS guide):

Create the file dns-addon-coreos.yaml:
(It is actually creating 2 different Kubernetes objects, separated by ---.)

```
[fedora@kube-master ~]$ cat dns-addon-coreos.yaml 
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "KubeDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: 10.254.0.10
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP

---

apiVersion: v1
kind: ReplicationController
metadata:
  name: kube-dns-v11
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    version: v11
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: kube-dns
    version: v11
  template:
    metadata:
      labels:
        k8s-app: kube-dns
        version: v11
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - name: etcd
        image: gcr.io/google_containers/etcd-amd64:2.2.1
        resources:
          limits:
            cpu: 100m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 50Mi
        command:
        - /usr/local/bin/etcd
        - -data-dir
        - /var/etcd/data
        - -listen-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -advertise-client-urls
        - http://127.0.0.1:2379,http://127.0.0.1:4001
        - -initial-cluster-token
        - skydns-etcd
        volumeMounts:
        - name: etcd-storage
          mountPath: /var/etcd/data
      - name: kube2sky
        image: gcr.io/google_containers/kube2sky:1.14
        resources:
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        args:
        # command = "/kube2sky"
        - --domain=cluster.local
      - name: skydns
        image: gcr.io/google_containers/skydns:2015-10-13-8c72f8c
        resources:
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        args:
        # command = "/skydns"
        - -machines=http://127.0.0.1:4001
        - -addr=0.0.0.0:53
        - -ns-rotate=false
        - -domain=cluster.local.
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
      - name: healthz
        image: gcr.io/google_containers/exechealthz:1.0
        resources:
          limits:
            cpu: 10m
            memory: 20Mi
          requests:
            cpu: 10m
            memory: 20Mi
        args:
        - -cmd=nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
        - -port=8080
        ports:
        - containerPort: 8080
          protocol: TCP
      volumes:
      - name: etcd-storage
        emptyDir: {}
      dnsPolicy: Default
[fedora@kube-master ~]$ 

```


```
[fedora@kube-master ~]$ kubectl create -f dns-addon-coreos.yaml 
service "kube-dns" created
replicationcontroller "kube-dns-v11" created
[fedora@kube-master ~]$ 
```

```
[fedora@kube-master ~]$ kubectl get pods --namespace=kube-system | grep kube-dns-v11
kube-dns-v11-7gjrz   3/4       Running   2          3m
[fedora@kube-master ~]$ 
```
There should be total of four containers running in the kube-dns-v11 pod, whereas there are only 3/4 running.There seems to be a problem.


Test by running a busybox container:
```
[fedora@kube-master ~]$ kubectl exec busybox -i -t -- sh


/ # nslookup kubernetes
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes'
/ # 



/ # nslookup yahoo.com
Server:    10.254.0.10
Address 1: 10.254.0.10

Name:      yahoo.com
Address 1: 2001:4998:c:a06::2:4008 ir1.fp.vip.gq1.yahoo.com
Address 2: 2001:4998:44:204::a7 ir1.fp.vip.ne1.yahoo.com
Address 3: 2001:4998:58:c02::a9 ir1.fp.vip.bf1.yahoo.com
Address 4: 206.190.36.45 ir1.fp.vip.gq1.yahoo.com
Address 5: 98.138.253.109 ir1.fp.vip.ne1.yahoo.com
Address 6: 98.139.183.24 ir2.fp.vip.bf1.yahoo.com
/ # 

```
There seems to be some problem. resolving yahoo.com takes forever. While the name kubernetes does not resolv at all! 




## Modify kubectl (config) to use skyDNS:

On all worker nodes:
```
-bash-4.3# vi /etc/kubernetes/kubelet 
KUBELET_ADDRESS="--address=192.168.124.11"
KUBELET_HOSTNAME="--hostname-override=192.168.124.11"
KUBELET_API_SERVER="--api-servers=http://192.168.124.10:8080"
KUBELET_ARGS="--cluster-dns=10.254.0.10  --cluster-domain=cluster.local"
```


Restart the kubelet service on each worker node:

```
service kubelet restart
``` 

Check status of the service. Look for the parameters/arguments you specified in the kubelet config file. They should appear in the output.

```
-bash-4.3# service kubelet status -l
Redirecting to /bin/systemctl status  -l kubelet.service
● kubelet.service - Kubernetes Kubelet Server
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since Mon 2016-06-06 12:16:43 UTC; 24s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 20702 (kubelet)
   Memory: 13.1M
      CPU: 429ms
   CGroup: /system.slice/kubelet.service
           ├─20702 /usr/bin/kubelet --logtostderr=true --v=0 --api-servers=http://192.168.124.10:8080 --address=192.168.124.11 --hostname-override=192.168.124.11 --allow-privileged=false --cluster-dns=10.254.0.10 --cluster-domain=cluster.local
           └─20738 journalctl -k -f

Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.658991   20702 server.go:109] Starting to listen on 192.168.124.11:10250
Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.905557   20702 kubelet.go:1150] Node 192.168.124.11 was previously registered
Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.976992   20702 factory.go:233] Registering Docker factory
Jun 06 12:16:46 kube-node1.example.com kubelet[20702]: I0606 12:16:46.977742   20702 factory.go:97] Registering Raw factory
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.100328   20702 manager.go:1003] Started watching for new ooms in manager
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.102218   20702 oomparser.go:182] oomparser using systemd
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.102584   20702 manager.go:256] Starting recovery of all containers
Jun 06 12:16:47 kube-node1.example.com kubelet[20702]: I0606 12:16:47.209300   20702 manager.go:261] Recovery completed
-bash-4.3# 
```

You need to recreate your pods after you setup SkyDNS, because they (pods) still don't know abot the new DNS service. Since kubelet service is restarted on the nodes, when new pods are created, kubelet will inject the DNS information in the pods (so to speak).



Now lets login to a container and see if it can see and use our DNS:

```
[fedora@kube-master ~]$ kubectl exec my-nginx-3800858182-3fs4y -i -t -- bash
```

Notice that our DNS is the first one listed in the container's /etc/resolv.conf:
```
root@my-nginx-3800858182-3fs4y:/# cat /etc/resolv.conf 
search default.svc.cluster.local svc.cluster.local cluster.local example.com
nameserver 10.254.0.10
nameserver 192.168.124.1
options ndots:5
root@my-nginx-3800858182-3fs4y:/#
```


## Problem running skydns and solution:

SkyDNS is not working properly. So troubleshooting is as follows:

I see the following:


First, the state of RC, SVC and pods:


```
[fedora@kube-master ~]$ kubectl logs  kube-dns-v11-7gjrz kube2sky  --namespace=kube-system 
I0606 14:42:29.609875       1 kube2sky.go:462] Etcd server found: http://127.0.0.1:4001
I0606 14:42:30.691607       1 kube2sky.go:529] Using http://localhost:8080 for kubernetes master
I0606 14:42:30.692206       1 kube2sky.go:530] Using kubernetes API <nil>
I0606 14:42:30.692584       1 kube2sky.go:598] Waiting for service: default/kubernetes
I0606 14:42:30.693686       1 kube2sky.go:604] Ignoring error while waiting for service default/kubernetes: yaml: mapping values are not allowed in this context. Sleeping 1s before retrying.
```

May be the container is expecting kubernetes master to be on localhost, whereas it is on 192.168.124.10 ! (I was right! See below!) 



I modified the kube2sky section in dns-addon-coreos.yaml by adding `--kube-master-url=http://192.168.124.10:8080` as an additional **args**. (Some guides suggest using `--kube_master_url`.)

```
[snipped]
. . . 
      - name: kube2sky
        image: gcr.io/google_containers/kube2sky:1.14
        resources:
          limits:
            cpu: 100m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          initialDelaySeconds: 30
          timeoutSeconds: 5
        args:
        # command = "/kube2sky"
        - --domain=cluster.local
        - --kube-master-url=http://192.168.124.10:8080
. . . 
[snipped]
```


, and I got the following in logs:

```
[fedora@kube-master ~]$ kubectl create -f dns-addon-coreos.yaml 
service "kube-dns" created
replicationcontroller "kube-dns-v11" created
[fedora@kube-master ~]$ 

[fedora@kube-master ~]$ kubectl get pods --namespace=kube-system
NAME                 READY     STATUS    RESTARTS   AGE
kube-dns-v11-5ndxj   4/4       Running   0          2m
[fedora@kube-master ~]$ 


[fedora@kube-master ~]$ kubectl logs kube-dns-v11-5ndxj kube2sky --namespace=kube-system
I0606 19:16:35.170516       1 kube2sky.go:462] Etcd server found: http://127.0.0.1:4001
I0606 19:16:36.172404       1 kube2sky.go:529] Using http://192.168.124.10:8080 for kubernetes master
I0606 19:16:36.172870       1 kube2sky.go:530] Using kubernetes API v1
I0606 19:16:36.173259       1 kube2sky.go:598] Waiting for service: default/kubernetes
I0606 19:16:36.227287       1 kube2sky.go:660] Successfully added DNS record for Kubernetes service.
[fedora@kube-master ~]$ 
``` 
Looks great!

Lets test:
Reference: [https://github.com/kubernetes/kubernetes/tree/release-1.2/cluster/addons/dns#how-do-i-test-if-it-is-working](https://github.com/kubernetes/kubernetes/tree/release-1.2/cluster/addons/dns#how-do-i-test-if-it-is-working)
```
[fedora@kube-master ~]$ kubectl create -f busybox.yaml 
pod "busybox" created
[fedora@kube-master ~]$ 

[fedora@kube-master ~]$ kubectl get pods
NAME      READY     STATUS    RESTARTS   AGE
busybox   1/1       Running   0          4m
[fedora@kube-master ~]$ 
```

```
[fedora@kube-master ~]$ kubectl exec busybox -i -t  -- sh

/ # nslookup yahoo.com
Server:    10.254.0.10
Address 1: 10.254.0.10

Name:      yahoo.com
Address 1: 2001:4998:58:c02::a9 ir1.fp.vip.bf1.yahoo.com
Address 2: 2001:4998:c:a06::2:4008 ir1.fp.vip.gq1.yahoo.com
Address 3: 2001:4998:44:204::a7 ir1.fp.vip.ne1.yahoo.com
Address 4: 206.190.36.45 ir1.fp.vip.gq1.yahoo.com
Address 5: 98.138.253.109 ir1.fp.vip.ne1.yahoo.com
Address 6: 98.139.183.24 ir2.fp.vip.bf1.yahoo.com
/ #
```

This time the reponse is instantaneous. Still it cannot resolve kubernetes!

```
/ # nslookup kubernetes
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes'
/ # nslookup kubernetes.default
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes.default'
/ # nslookup kubernetes.cluster.local
Server:    10.254.0.10
Address 1: 10.254.0.10

nslookup: can't resolve 'kubernetes.cluster.local'
/ # 
```

SkyDNS has something in the logs:
```
[fedora@kube-master ~]$ kubectl logs kube-dns-v11-5ndxj skydns --namespace=kube-system
2016/06/06 19:16:36 skydns: falling back to default configuration, could not read from etcd: 100: Key not found (/skydns/config) [15]
2016/06/06 19:16:36 skydns: ready for queries on cluster.local. for tcp://0.0.0.0:53 [rcache 0]
2016/06/06 19:16:36 skydns: ready for queries on cluster.local. for udp://0.0.0.0:53 [rcache 0]
[fedora@kube-master ~]$ 
```

Also the Healthz container:

```
2016/06/06 19:49:33 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:35 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:37 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:39 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:41 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:42 Client ip 172.16.18.1:58812 requesting /healthz probe servicing cmd nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:43 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
2016/06/06 19:49:45 Worker running nslookup kubernetes.default.svc.cluster.local 127.0.0.1 >/dev/null
[fedora@kube-master ~]$ 
``` 
Need to have a look at this: [https://github.com/kubernetes/kubernetes/issues/11634](https://github.com/kubernetes/kubernetes/issues/11634)



SkyDNS troubleshooting:

```
[fedora@kube-master ~]$ kubectl --namespace=kube-system  exec -ti kube-dns-v11-5ndxj -c skydns sh
/ # nslookup kubernetes.default.svc.cluster.local
Server:    192.168.124.1
Address 1: 192.168.124.1

nslookup: can't resolve 'kubernetes.default.svc.cluster.local'


/ # nslookup kubernetes.default.svc.cluster.local localhost
Server:    127.0.0.1
Address 1: 127.0.0.1 localhost

Name:      kubernetes.default.svc.cluster.local
Address 1: 10.254.0.1
/ # 
```

Looks like skydns is contacting the main dns server outside the kubernetes cluster!

```
/ # cat /etc/resolv.conf 
search example.com
nameserver 192.168.124.1
options ndots:5
/ # 
``` 


I have changed the nameserver to only 127.0.0.1 in the skyDNS container. So the file looks like this:

```
/ # cat /etc/resolv.conf 
nameserver 127.0.0.1
options ndots:5
/ # 
``` 



Lets see if my setup is working:

```
[fedora@kube-master ~]$ kubectl create -f run-my-nginx.yaml 
deployment "my-nginx" created
[fedora@kube-master ~]$
``` 


```
[fedora@kube-master ~]$ kubectl get pods
NAME                        READY     STATUS    RESTARTS   AGE
busybox                     1/1       Running   0          8m
my-nginx-3800858182-68ndj   1/1       Running   0          4m
my-nginx-3800858182-byhf9   1/1       Running   0          4m
[fedora@kube-master ~]$
```


```
[fedora@kube-master ~]$  kubectl expose deployment/my-nginx 
service "my-nginx" exposed
[fedora@kube-master ~]$ 
```

Lets see if busybox container can resolve the name of the new service:

```
[fedora@kube-master ~]$ kubectl exec busybox --  nslookup my-nginx.default.svc.cluster.local 
Server:    192.168.124.1
Address 1: 192.168.124.1

nslookup: can't resolve 'my-nginx.default.svc.cluster.local'
error: error executing remote command: Error executing command in container: Error executing in Docker Container: 1
[fedora@kube-master ~]$ 
```

Looks like it cannot! But when I pass it the IP address of the name server, it resolves the new service correctly:

```
[fedora@kube-master ~]$ kubectl exec busybox --  nslookup my-nginx.default.svc.cluster.local  10.254.0.10
Server:    10.254.0.10
Address 1: 10.254.0.10

Name:      my-nginx.default.svc.cluster.local
Address 1: 10.254.57.140
[fedora@kube-master ~]$ 
```


Q- Why the busybox container does not have the IP of the name server in it's resolv.conf file? kubelet is supposed to do that for all containers. 

A- This is happening because I rebuilt the worker nodes, and the custom setting for kubelet (which injects correct DNS into containers) is not there anymore. I think I have to make it part of my template files now.

```
[fedora@kube-master ~]$ kubectl exec busybox -- cat /etc/resolv.conf
search example.com
nameserver 192.168.124.1
options ndots:5
[fedora@kube-master ~]$ 
```


If this is fixed DNS will work properly - God willing. 


So I fix the kubelet service on all worker nodes and restart the kubelet service on all nodes.

(Only one node is shown here, you do this step on all nodes).

```
[fedora@kube-node1 ~]$ sudo -i
-bash-4.3# vi /etc/kubernetes/kubelet 
KUBELET_ADDRESS="--address=192.168.124.11"
KUBELET_HOSTNAME="--hostname-override=192.168.124.11"
KUBELET_API_SERVER="--api-servers=http://192.168.124.10:8080"
# KUBELET_ARGS=""
KUBELET_ARGS="--cluster-dns=10.254.0.10  --cluster-domain=cluster.local"


-bash-4.3# service kubelet restart

-bash-4.3# service kubelet status -l
Redirecting to /bin/systemctl status  -l kubelet.service
● kubelet.service - Kubernetes Kubelet Server
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-06-10 14:32:32 UTC; 11s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 3914 (kubelet)
   Memory: 13.6M
      CPU: 473ms
   CGroup: /system.slice/kubelet.service
           ├─3914 /usr/bin/kubelet --logtostderr=true --v=0 --api-servers=http://192.168.124.10:8080 --address=192.168.124.11 --hostname-override=192.168.124.11 --allow-privileged=false --cluster-dns=10.254.0.10 --cluster-domain=cluster.local
           └─3940 journalctl -k -f

Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.069245    3914 kubelet.go:2372] Starting kubelet main sync loop.
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.069503    3914 kubelet.go:2381] skipping pod synchronization - [container runtime is down]
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.070153    3914 server.go:109] Starting to listen on 192.168.124.11:10250
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.288511    3914 kubelet.go:1150] Node 192.168.124.11 was previously registered
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.372066    3914 factory.go:233] Registering Docker factory
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.372890    3914 factory.go:97] Registering Raw factory
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.500811    3914 manager.go:1003] Started watching for new ooms in manager
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.504548    3914 oomparser.go:182] oomparser using systemd
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.510507    3914 manager.go:256] Starting recovery of all containers
Jun 10 14:32:35 kube-node1.example.com kubelet[3914]: I0610 14:32:35.621128    3914 manager.go:261] Recovery completed
-bash-4.3# 
```

Then I restart the busybox container, which I am using to test the DNS. 

```
[fedora@kube-master ~]$ kubectl delete pod busybox 
pod "busybox" deleted
[fedora@kube-master ~]$ 

[fedora@kube-master ~]$ kubectl create -f busybox.yaml 
pod "busybox" created

[fedora@kube-master ~]$ kubectl get pods
NAME                        READY     STATUS    RESTARTS   AGE
busybox                     1/1       Running   0          10s
[fedora@kube-master ~]$ 
```


The skydns only resolves the name locally, the pods / containers are not able to resolve the name kubernetes.default.svc.cluster.local even though their resolv.conf points to correct cluster DNS IP address. This is becoming stange!


```
[fedora@kube-master ~]$  kubectl --namespace=kube-system  exec -ti  kube-dns-v11-iy7yr -c skydns sh 
/ # nslookup my-nginx
Server:    127.0.0.1
Address 1: 127.0.0.1 localhost

nslookup: can't resolve 'my-nginx'
/ # nslookup my-nginx.default.svc.cluster.local
Server:    127.0.0.1
Address 1: 127.0.0.1 localhost

Name:      my-nginx.default.svc.cluster.local
Address 1: 10.254.70.25
/ # nslookup yahoo.com
Server:    127.0.0.1
Address 1: 127.0.0.1 localhost

Name:      yahoo.com
Address 1: 206.190.36.45 ir1.fp.vip.gq1.yahoo.com
Address 2: 98.138.253.109 ir1.fp.vip.ne1.yahoo.com
Address 3: 98.139.183.24 ir2.fp.vip.bf1.yahoo.com
/ # 
```


May be the sky DNS container is not listening on the cluster IP or All IP addresses?



