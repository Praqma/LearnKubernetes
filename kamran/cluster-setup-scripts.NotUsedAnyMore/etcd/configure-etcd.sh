INTERNAL_IP=$(ip addr show ens3 | grep -w inet | awk '{print $2}' | cut -f1 -d '/')
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
