#!/bin/bash

# Setup etcd nodes
# Before setting up etcd nodes, it is important for nodes to have operator's public key in /root/.ssh/authorized_keys file
# Need to do ssh rsa scan for fingerprint of all nodes before moving on.

SCRIPT_PATH=$(dirname $0)
pushd $(pwd)
cd $SCRIPT_PATH


# Create service file 

echo "Creating the etcd unit file...."

cat > etcd.service <<"ETCDEOF"
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/bin/etcd --name ETCD_NAME \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --initial-advertise-peer-urls https://INTERNAL_IP:2380 \
  --listen-peer-urls https://INTERNAL_IP:2380 \
  --listen-client-urls https://INTERNAL_IP:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://INTERNAL_IP:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster etcd1=https://ETCD1:2380,etcd2=https://ETCD2:2380,etcd3=https://ETCD3:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
ETCDEOF


echo "Creating configure-etcd.sh script ..."

cat > configure-etcd.sh <<"CONFIGUREEETCDEOF"
# The < sign is important in the line below.
NET_IFACE=$(ip addr | grep -w '<BROADCAST,MULTICAST,UP' | awk -F: '{print $2}')
INTERNAL_IP=$(ip addr show ${NET_IFACE} | grep -w inet | awk '{print $2}' | cut -f1 -d '/')
ETCD_NAME=$(hostname -s)
ETCD1=$(grep -v \# /etc/hosts  | grep etcd1 | awk '{print $2}')
ETCD2=$(grep -v \# /etc/hosts  | grep etcd2 | awk '{print $2}')
ETCD3=$(grep -v \# /etc/hosts  | grep etcd3 | awk '{print $2}')

sed -i -e s/INTERNAL_IP/$INTERNAL_IP/g \
       -e s/ETCD_NAME/$ETCD_NAME/g     \
       -e s/ETCD1/$ETCD1/g    \
       -e s/ETCD2/$ETCD2/g    \
       -e s/ETCD3/$ETCD3/g    \
       /root/etcd.service

mv /root/etcd.service /etc/systemd/system/
CONFIGUREEETCDEOF

chmod +x configure-etcd.sh


# check if certs are there 
if [ -f ../certs/kubernetes.pem ] && [ -f ../certs/kubernetes-key.pem ]  && [ -f ../certs/ca.pem ] ; then
  echo "Certs present in ../certs"
else
  echo "Certs not found in ../certs . Cannot continue ..."
  popd
  exit 9
fi


echo "Installing etcd software on all etcd nodes ..."
for node in $(grep etcd /etc/hosts | grep -v \# | awk '{print $2}'); do
  echo ${node}
  ssh root@${node} "mkdir -p /etc/etcd; service etcd stop; curl -L https://github.com/coreos/etcd/releases/download/v3.0.14/etcd-v3.0.14-linux-amd64.tar.gz -o /root/etcd-v3.0.14-linux-amd64.tar.gz && tar xzf /root/etcd-v3.0.14-linux-amd64.tar.gz -C /usr/bin/ --strip-components=1 && /usr/bin/etcd --version ; mkdir -p /var/lib/etcd"
  echo "Copying certs ..."
  scp ../certs/*.pem root@${node}:/etc/etcd/
  scp /etc/hosts root@${node}:/etc/hosts
  scp etcd.service root@${node}:/root/
  scp configure-etcd.sh root@${node}:/root/
  echo "Running the configure-etcd.sh script on node ${node}"
  ssh root@${node} "chmod +x /root/configure-etcd.sh ; /root/configure-etcd.sh"
done

# A note about tcd ports: [https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=etcd](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml?search=etcd)
# etcd-client	2379	tcp	etcd client communication
# etcd-server	2380	tcp	etcd server to server communication


echo "Starting etcd on etcd nodes ..."

for node in $(grep etcd /etc/hosts | grep -v \# | awk '{print $2}'); do
  echo ${node}
  ssh root@${node} "systemctl daemon-reload; systemctl enable etcd; systemctl start etcd"
  sleep 3
  ssh root@${node} "systemctl status etcd  --no-pager -l"
done


echo "Checking etcd cluster health... Also, checking which node is the leader in this cluster."
for node in $(grep etcd /etc/hosts | grep -v \# | awk '{print $2}'); do
  echo ${node}
  ssh root@${node} "etcdctl --ca-file=/etc/etcd/ca.pem cluster-health"
  ssh root@${node} "curl --connect-timeout 2 --max-time 3 -s http://127.0.0.1:2379/v2/stats/leader"
done

# All done, now change directory to the place we came from.
popd




