# Load Balancer


Our tfhosts.txt looks like this:

```
52.220.201.1    controller1
52.220.200.175  controller2
52.220.102.101  etcd1
52.74.30.173    etcd2
52.220.201.44   etcd3
52.74.35.66     lb1
52.77.160.219   lb2
52.220.188.86   worker1
52.76.72.19     worker2

```

Out /etc/hosts file on all nodes look like this:

```
[root@controller1 ~]# cat /etc/hosts
127.0.0.1       localhost.localdomain localhost
172.32.10.43    controller1.example.com
172.32.10.61    controller2.example.com
172.32.10.70    controller.example.com
172.32.10.84    etcd1.example.com
172.32.10.73    etcd2.example.com
172.32.10.239   etcd3.example.com
172.32.10.162   lb1.example.com
172.32.10.40    lb2.example.com
172.32.10.50    lb.example.com
172.32.10.105   worker1.example.com
172.32.10.68    worker2.example.com
[root@controller1 ~]# 

```



## Install necessary software on the load balancer nodes:

```
for node in $(cat tfhosts.txt | grep lb | cut -f1 -d$'\t' ); do
  echo "Processing node: ${node}"
  ssh root@${node}  "yum -y install jq haproxy pacemaker pcs corosync psmisc nginx"

  echo "Enabling and staring PCSD service ..."
  ssh root@${node} "systemctl enable pcsd.service; systemctl stop pcsd.service; systemctl start pcsd.service"
  echo "---------------------------------------------------"
done

sleep 5
```





## Install and configure Kubernetes software on Worker nodes.

```
for node in $(cat tfhosts.txt | grep lb | cut -f1 -d$'\t' ); do
  echo "Processing node: ${node}"
  scp configure-lb.sh root@${node}:/root/
  ssh root@${node} "/root/configure-lb.sh"
  echo "---------------------------------------------------"
done

sleep 5
```



