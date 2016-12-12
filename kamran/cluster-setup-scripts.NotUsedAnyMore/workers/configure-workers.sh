#!/bin/bash

# Configures worker nodes...

CONTROLLER_VIP=$(grep -v \# /etc/hosts | grep "controller\." | awk '{print $1}')


if [ ! -f ca.pem ] || [ ! -f kubernetes-key.pem ] || [ ! -f  kubernetes.pem ] ; then
  echo "Certs not found in /root/"
  exit 9
fi 

echo "Creating /var/lib/kubernetes and moving in certificates ..."
mkdir -p /var/lib/kubernetes
mv  ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/


# Downloading software is already done in the parent script.
# echo "Downloading software components ...."
# echo
# echo "Docker..."
# curl -# -z docker-1.12.3.tgz -O https://get.docker.com/builds/Linux/x86_64/docker-1.12.3.tgz

# echo
# echo "Kubernetes worker components ..."
# curl -# -z kubectl -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kubectl
# curl -# -z kube-proxy -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kube-proxy
# curl -# -z kubelet -O https://storage.googleapis.com/kubernetes-release/release/v1.3.10/bin/linux/amd64/kubelet

tar xzf docker-1.12.3.tgz -C /usr/bin/  --strip-components=1

# delete tarfile later.

chmod +x /root/kube* 

mv  kube* /usr/bin/

echo "Configuring docker service ..."

cat > /etc/systemd/system/docker.service << DOCKEREOF
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.io

[Service]
ExecStart=/usr/bin/docker daemon \
  --iptables=false \
  --ip-masq=false \
  --host=unix:///var/run/docker.sock \
  --log-level=error \
  --storage-driver=overlay
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
DOCKEREOF



echo "Enable and start docker service ..."

systemctl daemon-reload
systemctl enable docker
systemctl stop docker
sleep 3
systemctl start docker
sleep 3

docker version




echo "Download and install CNI plugins for kubernetes usage"

mkdir -p /opt/cni

# Downloaded already in the parent script.
# curl -O https://storage.googleapis.com/kubernetes-release/network-plugins/cni-c864f0e1ea73719b8f4582402b0847064f9883b0.tar.gz
# curl -z -O https://storage.googleapis.com/kubernetes-release/network-plugins/cni-amd64-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz

tar xzf cni-amd64-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz -C /opt/cni


echo "Configure K8s worker components ..."

echo "Configuring kubelet ..."


mkdir -p /var/lib/kubelet/

cat > /var/lib/kubelet/kubeconfig << KUBECONFIGEOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://${CONTROLLER_VIP}:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubelet
  name: kubelet
current-context: kubelet
users:
- name: kubelet
  user:
    token: chAng3m3
KUBECONFIGEOF



echo "Creating the kubelet systemd unit file ..."

cat > /etc/systemd/system/kubelet.service << KUBELETEOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \
  --allow-privileged=true \
  --api-servers=https://${CONTROLLER_VIP}:6443 \
  --cloud-provider= \
  --cluster-dns=10.32.0.10 \
  --cluster-domain=cluster.local \
  --configure-cbr0=true \
  --container-runtime=docker \
  --docker=unix:///var/run/docker.sock \
  --network-plugin=kubenet \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --reconcile-cidr=true \
  --serialize-image-pulls=false \
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
KUBELETEOF



echo "Starting the kubelet service and check that it is running ..."

systemctl daemon-reload
systemctl enable kubelet
systemctl stop kubelet
sleep 3
systemctl start kubelet
sleep 3

systemctl status kubelet --no-pager -l




echo "Creating systemd unit file for kube-proxy ..."

cat > /etc/systemd/system/kube-proxy.service << KUBEPROXYEOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy \
  --master=https://${CONTROLLER_VIP}:6443 \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --proxy-mode=iptables \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
KUBEPROXYEOF


systemctl daemon-reload
systemctl enable kube-proxy
systemctl stop kube-proxy
sleep 3

systemctl start kube-proxy
sleep 3

systemctl status kube-proxy --no-pager -l



#################################################################



