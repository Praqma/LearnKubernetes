#!/bin/bash

# Configures worker nodes...

CONTROLLER_VIP=172.32.10.70


echo "Creating /var/lib/kubernetes and moving in certificates ..."
mkdir -p /var/lib/kubernetes

mv -f ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/


echo "Installing necessary software components ..."

yum -y install haproxy git jq


echo "Downloading software components ...."


echo
echo "Kubernetes kube-proxy and kubectl components ..."
echo "Todo: Actually, we do not need these components to run our LB, as api reader connects to controllers using curl..."
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-proxy
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kubectl


chmod +x /root/kube* 

mv -f kube* /usr/bin/



echo
echo "Downloading latest version of Praqma's k8s Cloud LoadBalancer"
git clone https://github.com/Praqma/k8s-cloud-loadbalancer.git


echo "Configuring haproxy with default config file from our repository ..."
cp  k8s-cloud-loadbalancer/lb-nodeport/haproxy.cfg.global-defaults /etc/haproxy/haproxy.cfg 

echo "Enabling haproxy service ..."
# This should ideally be controlled by pacemaker. Since we do not have HA in AWS, we will just start the service on lb node 1.
# Though starting haproxy on both nodes does not harm either.

systemctl enable haproxy
systemctl stop haproxy
systemctl start haproxy
sleep 5
systemctl status haproxy --no-pager -l 





############################################# 



