#!/bin/bash

echo "Creating /var/lib/kubernetes and moving in certificates ..."

if [ -f kubernetes.pem ] && [ -f kubernetes-key.pem ] && [ -f ca.pem ] ; then
  # Assuming certs are present in /root/
  mkdir -p /var/lib/kubernetes
  mv -v ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
else
  echo "Certificates missing in /root/. Exiting ..."
  exit 9
fi


############
#
# This section is already taken care of in master controllers.sh script. Files are downloaded on technician computer,
# , and then copied to nodes directly in /usr/bin/ . 
#
# echo "Downloading Kubernetes software components ..."

# curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-apiserver
# curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-controller-manager
# curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-scheduler
# curl -# -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kubectl

# chmod +x /root/kube* 

# echo "Installing Kubernetes software components into /usr/bin/"
# mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/
#
############

echo "Downloading token.csv and authorization-policy.json ... into /var/lib/kubernetes/"
curl -# -O  https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/token.csv

cat token.csv

mv token.csv /var/lib/kubernetes/

curl -# -O  https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/authorization-policy.jsonl
mv authorization-policy.jsonl /var/lib/kubernetes/



# Find and set the INTERNAL_IP of node.
# The < sign is important in the line below.
NET_IFACE=$(ip addr | grep -w '<BROADCAST,MULTICAST,UP' | awk -F: '{print $2}')
INTERNAL_IP=$(ip addr show ${NET_IFACE} | grep -w inet | grep '/24' | awk '{print $2}' | cut -f1 -d '/')

echo
echo "Node INTERNAL_IP found to be: $INTERNAL_IP"
echo


echo "Creating Kubernetes API server file ...."

cat > kube-apiserver.service <<"APIEOF"
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-apiserver \
  --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota \
  --advertise-address=INTERNAL_IP \
  --allow-privileged=true \
  --apiserver-count=2 \
  --authorization-mode=ABAC \
  --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl \
  --bind-address=0.0.0.0 \
  --enable-swagger-ui=true \
  --etcd-cafile=/var/lib/kubernetes/ca.pem \
  --insecure-bind-address=0.0.0.0 \
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
  --etcd-servers=https://ETCD1:2379,https://ETCD2:2379,https://ETCD3:2379 \
  --service-account-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --service-cluster-ip-range=10.32.0.0/24 \
  --service-node-port-range=30000-32767 \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --token-auth-file=/var/lib/kubernetes/token.csv \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
APIEOF

ETCD1=$(grep -v \# /etc/hosts  | grep etcd1 | awk '{print $2}')
ETCD2=$(grep -v \# /etc/hosts  | grep etcd2 | awk '{print $2}')
ETCD3=$(grep -v \# /etc/hosts  | grep etcd3 | awk '{print $2}')

sed -i -e s/INTERNAL_IP/$INTERNAL_IP/g \
       -e s/ETCD1/$ETCD1/g    \
       -e s/ETCD2/$ETCD2/g    \
       -e s/ETCD3/$ETCD3/g    \
  kube-apiserver.service


cp kube-apiserver.service /etc/systemd/system/


echo "Creating controller manager service file ..."

cat > kube-controller-manager.service <<"MANAGEREOF"
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-controller-manager \
  --allocate-node-cidrs=true \
  --cluster-cidr=10.200.0.0/16 \
  --cluster-name=kubernetes \
  --leader-elect=true \
  --master=http://INTERNAL_IP:8080 \
  --root-ca-file=/var/lib/kubernetes/ca.pem \
  --service-account-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --service-cluster-ip-range=10.32.0.0/24 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
MANAGEREOF


sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-controller-manager.service
cp kube-controller-manager.service /etc/systemd/system/


echo "Creating scheduler file ..."

cat > kube-scheduler.service <<"SCHEDULEREOF"
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-scheduler \
  --leader-elect=true \
  --master=http://INTERNAL_IP:8080 \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SCHEDULEREOF



sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-scheduler.service
cp kube-scheduler.service /etc/systemd/system/

echo "Enabling and restarting k8s services using systemctl ... (will take about 10 seconds on each node)"

systemctl daemon-reload

systemctl enable kube-apiserver  kube-controller-manager  kube-scheduler 

systemctl stop  kube-apiserver  kube-controller-manager  kube-scheduler 
echo "services stopped ... sleeping 1 seconds" ; sleep 1

systemctl start  kube-apiserver  kube-controller-manager  kube-scheduler 
echo "services started ... sleeping 5 seconds" ; sleep 5


systemctl status kube-apiserver  kube-controller-manager  kube-scheduler  --no-pager -l

echo "The cluster status: (should be healthy): "
kubectl get componentstatuses
