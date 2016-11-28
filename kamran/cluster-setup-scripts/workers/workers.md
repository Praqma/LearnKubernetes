# Install and configure Kubernetes Worker nodes:

Our tfhosts.txt looks like this:

```
52.220.201.1	controller1
52.220.200.175	controller2
52.220.102.101	etcd1
52.74.30.173	etcd2
52.220.201.44	etcd3
52.74.35.66	lb1
52.77.160.219	lb2
52.220.188.86	worker1
52.76.72.19	worker2

```

Out /etc/hosts file on all nodes look like this:

```
[root@controller1 ~]# cat /etc/hosts
127.0.0.1	localhost.localdomain localhost
172.32.10.43 	controller1.example.com
172.32.10.61 	controller2.example.com
172.32.10.70	controller.example.com
172.32.10.84 	etcd1.example.com
172.32.10.73 	etcd2.example.com
172.32.10.239 	etcd3.example.com
172.32.10.162 	lb1.example.com
172.32.10.40 	lb2.example.com
172.32.10.50	lb.example.com
172.32.10.105 	worker1.example.com
172.32.10.68 	worker2.example.com
[root@controller1 ~]# 
```



## Install and configure Kubernetes software on Worker nodes.

```
for node in $(cat tfhosts.txt | grep worker | cut -f1 -d$'\t' ); do
  echo "Processing node: ${node}"
  scp configure-workers.sh root@${node}:/root/
  ssh root@${node} "/root/configure-workers.sh"
done

sleep 5
```

# Check status of nodes from master node:
```
ssh root@controller.example.com "kubectl get nodes"
```


# Now we need nodes' IP subnets so we can add them to the router.
```
ssh root@controller.example.com "kubectl describe node worker1 worker2 | egrep 'Name|PodCIDR' " 
```


```
kubectl get nodes \
  --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
```


```
[root@controller1 ~]# kubectl get nodes \
>   --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
172.32.10.105 10.200.0.0/24 
172.32.10.68 10.200.1.0/24 
[root@controller1 ~]# 
```



Lets get the routing table ID for the routing table connected to our VPC (and it should say "YES" in column "Main" OR Main =True ).


Meanwhile, lets have two pods, (ideally on two different nodes):

```
[root@controller1 ~]# kubectl get nodes
NAME                  STATUS    AGE
worker1.example.com   Ready     18h
worker2.example.com   Ready     18h


[root@controller1 ~]# kubectl get pods


[root@controller1 ~]# kubectl run network-multitool --image praqma/network-multitool --replicas 2
deployment "network-multitool" created


[root@controller1 ~]# kubectl get pods
NAME                                 READY     STATUS              RESTARTS   AGE
network-multitool-2164695616-nxvvk   0/1       ContainerCreating   0          8s
network-multitool-2164695616-zsoh3   0/1       ContainerCreating   0          8s
[root@controller1 ~]# 
```


```
[root@controller1 ~]# kubectl get pods -o wide
NAME                                 READY     STATUS    RESTARTS   AGE       IP           NODE
network-multitool-2164695616-nxvvk   1/1       Running   0          1m        10.200.0.2   worker1.example.com
network-multitool-2164695616-zsoh3   1/1       Running   0          1m        10.200.1.2   worker2.example.com
[root@controller1 ~]# 
```


```
[root@controller1 ~]# kubectl exec -it network-multitool-2164695616-nxvvk bash
[root@network-multitool-2164695616-nxvvk /]# ping 10.200.1.2
PING 10.200.1.2 (10.200.1.2) 56(84) bytes of data.
^C
--- 10.200.1.2 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss, time 2999ms

[root@network-multitool-2164695616-nxvvk /]# 
```


Figure this error later:

```
[root@network-multitool-2164695616-nxvvk /]# exit
exit
error: error executing remote command: error executing command in container: Error executing in Docker Container: 1
[root@controller1 ~]#
```



Lets do the routing thing in AWS

```
[root@controller1 ~]# aws ec2 describe-route-tables   --filters "Name=tag:By,Values=Praqma"  | jq -r '.RouteTables[].RouteTableId'
rtb-88ab18ec
[root@controller1 ~]# 

```

```
[root@controller1 ~]# kubectl get nodes   --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
172.32.10.105 10.200.0.0/24 
172.32.10.68 10.200.1.0/24 
[root@controller1 ~]# 
```

```
[root@controller1 ~]# aws ec2 describe-instances   --filters "Name=tag:Name,Values=worker-1" |   jq -j '.Reservations[].Instances[].InstanceId'
i-ea6d806b
[root@controller1 ~]# 
```


```
[root@controller1 ~]#  aws ec2 describe-instances   --filters "Name=tag:Name,Values=worker-2" |   jq -j '.Reservations[].Instances[].InstanceId'
i-456d80c4
[root@controller1 ~]# 
```


```
[root@controller1 ~]# ROUTE_TABLE_ID=$(aws ec2 describe-route-tables   --filters "Name=tag:By,Values=Praqma"  | jq -r '.RouteTables[].RouteTableId')


[root@controller1 ~]# echo $ROUTE_TABLE_ID 
rtb-88ab18ec
[root@controller1 ~]# 
```


```
[root@controller1 ~]# WORKER_1_ID=$(aws ec2 describe-instances   --filters "Name=tag:Name,Values=worker-1" |   jq -j '.Reservations[].Instances[].InstanceId')
[root@controller1 ~]# WORKER_2_ID=$(aws ec2 describe-instances   --filters "Name=tag:Name,Values=worker-2" |   jq -j '.Reservations[].Instances[].InstanceId')
[root@controller1 ~]# 
```


```
aws ec2 create-route \
  --route-table-id ${ROUTE_TABLE_ID} \
  --destination-cidr-block 10.200.0.0/24 \
  --instance-id ${WORKER_1_ID}



aws ec2 create-route \
  --route-table-id ${ROUTE_TABLE_ID} \
  --destination-cidr-block 10.200.1.0/24 \
  --instance-id ${WORKER_2_ID}
```


Now the pods see each other:
```
[root@controller1 ~]# kubectl exec -it network-multitool-2164695616-nxvvk bash
[root@network-multitool-2164695616-nxvvk /]# ping 10.200.1.2
PING 10.200.1.2 (10.200.1.2) 56(84) bytes of data.
64 bytes from 10.200.1.2: icmp_seq=1 ttl=62 time=0.542 ms
64 bytes from 10.200.1.2: icmp_seq=2 ttl=62 time=0.495 ms
64 bytes from 10.200.1.2: icmp_seq=3 ttl=62 time=0.471 ms
^C
--- 10.200.1.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2000ms
rtt min/avg/max/mdev = 0.471/0.502/0.542/0.039 ms
[root@network-multitool-2164695616-nxvvk /]# 
```


Hurray!!!!



