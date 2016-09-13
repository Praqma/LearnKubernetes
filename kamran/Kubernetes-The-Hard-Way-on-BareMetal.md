# Kubernetes The Hard Way - Bare Metal

This document is going to be the last document in the series of Kubernetes the Hard Way. It follows Kelsey Hightower's turtorial [https://github.com/kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) , and attempts to make improvements and explanations where needed. So here we go.

# Target Audience
The target audience for this tutorial is someone planning to setup or support a production Kubernetes cluster and wants to understand how everything fits together. 

# Infrastructure:
I do not have actual bare metal. I have vitual machines, running on LibVirt/KVM on my work computer (Fedora 23 - 64 bit). Some may argue that I could have used Amazon AWS, and used VMs over there too. Well, I tried that , documented here: [Kubernetes-The-Hard-Way-on-AWS.md](Kubernetes-The-Hard-Way-on-AWS.md) , and it did not work when I reached Pod Networking on worker nodes. Amazon has it's VPC mechanism, and it did not let the traffic flow between two pod networks on two different worker nodes. May be I did not know how to get that done correctly, but this type of routing on AWS VPC is not documented either. So I had to abandon it. 


So, I am going to use VMs on my work computer to create this setup. But before I start building VMs, I want to mention few important things.

## Networking:
Kubernetes uses three different types of networks. They are:

* Infrastructure Network: The network your physical (or virtual) machines are connected to. Normally your production network, or a part of it.
* Service Network: The (completely) virtual (rather fictional) network, which is used to assign IP addresses to Kubernetes Services, which you will be creating. (A Service is a frontend to a RC or a Deployment). It must be noted that IP from this network are **never** assigned to any of the interfaces of any of the nodes/VMs, etc. These (Service IPs) are used behind the scenes by kube-proxy to create (weird) iptables rules on the worker nodes. 
* Pod Network: This is the network, which is used by the pods. However it is not a simple network either, depending on what kubernetes network solution you are employing. If you are using flannel, then this would be a large software defined overlay network, and each worker node will get a subnet of this network and configured for it's docker0 interface (in very simple words, there is a little more to it). If you are employing CIDR network, using CNI, then it would be a large network called **cluster-cidr** , with small subnets corresponding to your worker nodes. The routing table of the router handling your part of infrastructure network will need to be updated with routes to these small subnets. This proved to be a challenge on AWS VPC router, but this is piece of cake on a simple/generic router in your network. I will be doing it on my work computer, and setting up routes on Linux is a very simple task.

Kelsey used the following three networks in his guide, and I intend to use the same ones, so people following this guide, but checking his guide for reference are not confused in different IP schemes. So here are my three networks , which I will use for this guide.

* Infrastructure network:     10.240.0.0/24 
* Service Network:            10.32.0.0/24 
* Pod Network (Cluster CIDR): 10.200.0.0/16 


By default I have a virtual network 192.168.124.0/24 configured on my work computer, provided by libvirt. However, I want to be as close to Kelsey's guide as possible, so my infrastructure network is going to be 10.240.0.0/24 . I will just create a new virtual network (10.240.0.0/24) on my work computer.


The setup will look like this when finished:

(TODO) A network diagram here.



## DNS names:
It is understood that all nodes in this cluster will have some hostname assigned to them. It is important to have consistent hostnames, and if there is a DNS server in your infrastructure, then it is also important what are the reverse lookup names of these nodes. This information is  critical at the time when you will generate SSL certificates. 


## Operating System:
Fedora 24 64 bit server edition - on all nodes (Download from [here](https://getfedora.org/en/server/download/) ). Even though I wanted to use Fedora Atomic, I am not using that. It is because Fedora Atomic is a collection of binaries bundled together (in a read only  filesystem), and individual packages cannot be updated. There is no yum, etc. I am going to use latest version of Kubernetes 1.3, which is still not part of Fedora Atomic. 

# Expectations

A working kubernetes cluster with:
* 2 x etcd nodes (in H/A configuration) 
* 2 x Kubernetes controller nodes (in H/A configuration) 
* 2 x Kubernetes worker nodes
* SSL based communication between all Kubernetes components
* Internal Cluster DNS (SkyDNS) - as cluster addon
* Default Service accounts and Secrets


# Supporting software needed for this setup:
* Kubernetes - 1.3.0 or later (Download latest from Kubernetes website)
* etcd - 2.2.5 or later (The one that comes with Fedora is good enough)
* Docker - 1.11.2 or later (Download latest from Docker website)
* CNI networking [https://github.com/containernetworking/cni](https://github.com/containernetworking/cni)


# Infrastructure provisioning

Note that I am doing this provisioning on my work computer, which is Fedora 23 64 bit, and I will use the built in (the best) KVM for virtualization. 

First, setting up the new infrastructure network in KVM.

## Setup new virtual network in KVM:

Start Virtual Machine Manager and go to "Edit"->"Connection Details"->"Virtual Networks" . Then follow the steps shown below to create a new virtual network. Note that this is a NAT network, connected to any/all physical devices on my computer. So whether I am connected to wired network, or wireless, it will work.

![images/libvirt-new-virtual-network-1.png](images/libvirt-new-virtual-network-1.png)
![images/libvirt-new-virtual-network-2.png](images/libvirt-new-virtual-network-2.png)
![images/libvirt-new-virtual-network-3.png](images/libvirt-new-virtual-network-3.png)
![images/libvirt-new-virtual-network-4.png](images/libvirt-new-virtual-network-4.png)
![images/libvirt-new-virtual-network-5.png](images/libvirt-new-virtual-network-5.png)
![images/libvirt-new-virtual-network-6.png](images/libvirt-new-virtual-network-6.png)

The wizard will create an internal DNS setup (automatically) for example.com .

Now, we have the network out of the way, I will start creating VMs and attach them to this virtual network.

## Provision VMs in KVM:

Here are the sizes (and related IP addresses) of VMs I am creating:

* etcd1		512 MB RAM	4 GB disk	10.240.0.11/24
* etcd2		512 MB RAM	4 GB disk	10.240.0.12/24
* controller1	1 GB RAM	4 GB disk	10.240.0.21/24
* controller2	1 GB RAM	4 GB disk	10.240.0.22/24
* worker1	1.5 GB RAM	20 GB disk	10.240.0.31/24
* worker2	1.5 GB RAM	20 GB disk	10.240.0.32/24

As I mentioned earlier, there will be two controller nodes in HA mode. There is no internal mechanism for Kubernetes controllers to work as a cluster, so we will use a trick; which is, setup a (kind of) load balancer in front of the controller nodes. We need to decide on an IP address right now, becuase that will be used while we are creating the TLS certificates. I decided to use the IP address `10.240.0.20` to work as VIP (virtual IP / load balancer IP ) for the controller nodes.

**Notes:** 
* Kelsey's guide starts the node numbering from 0. I start them from 1, for ease of understanding.
* The FQDN of each host is *hostname*.example.com 
* The nodes have only one user, **root** ; password: redhat .
* I used GUI interface to create these VMs, but you can automate this by using CLI commands.


I have added a few screenshots, so people new to KVM have no problem doing this.
**Note:** One of the installation screen shows Fedora 22 on Installation Media selection screen, but it is actually Fedora 24. Libvirt is not updated yet to be aware of Fedora 24 images.

(TODO) Screenshots from fedora installation.

(TODO) Screenshot showing admin (web) interface (Cockpit) when logged in on login screen.



After all VMs are created. I do an OS update on them using `yum -y update`, disable firewalld service, and also disable SELINUX in `/etc/selinux/config` file and reboot all nodes for these changes to take effect. 

Though not absolutely necessary, I also installed my RSA (SSH) public key to root account of all nodes, so I can ssh into them without password.

```
[kamran@kworkhorse ~]$ ssh-copy-id root@10.240.0.11
The authenticity of host '10.240.0.11 (10.240.0.11)' can't be established.
ECDSA key fingerprint is SHA256:FUMy5JNZnaLXhkW3Y0/WlXzQQrjU5IZ8LMOcgBTOiLU.
ECDSA key fingerprint is MD5:5e:9b:2d:ae:8e:16:7a:ee:ca:de:de:da:9a:04:19:8b.
Are you sure you want to continue connecting (yes/no)? yes
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 2 key(s) remain to be installed -- if you are prompted now it is to install the new keys
root@10.240.0.11's password: 

Number of key(s) added: 2

Now try logging into the machine, with:   "ssh 'root@10.240.0.11'"
and check to make sure that only the key(s) you wanted were added.

[kamran@kworkhorse ~]$ 
```

You should be able to execute commands on the nodes now:
```
[kamran@kworkhorse ~]$ ssh root@10.240.0.11 uptime
 13:16:27 up  1:29,  1 user,  load average: 0.08, 0.03, 0.04
[kamran@kworkhorse ~]$ 
```

I also updated my /etc/hosts on my work computer:
```
[kamran@kworkhorse ~]$ sudo vi /etc/hosts
127.0.0.1               localhost.localdomain localhost
10.240.0.11     etcd1.example.com       etcd1
10.240.0.12     etcd2.example.com       etcd2
10.240.0.21     controller1.example.com controller1
10.240.0.22     controller2.example.com controller2
10.240.0.31     worker1.example.com     worker1
10.240.0.32     worker2.example.com     worker2
```


And, copied the same to all nodes.
```
[kamran@kworkhorse ~]$ scp /etc/hosts root@etcd1:/etc/hosts 
[kamran@kworkhorse ~]$ scp /etc/hosts root@etcd2:/etc/hosts 
[kamran@kworkhorse ~]$ scp /etc/hosts root@controller1:/etc/hosts 
[kamran@kworkhorse ~]$ scp /etc/hosts root@controller2:/etc/hosts 
[kamran@kworkhorse ~]$ scp /etc/hosts root@worker1:/etc/hosts 
[kamran@kworkhorse ~]$ scp /etc/hosts root@worker2:/etc/hosts 
```

Disable firewall on all nodes:
```
 # service firewalld stop; systemctl disable firewalld
```

Note: For some strange reason, disabling firewalld does not work. I had to actually remove the firewalld package from all of the nodes.
```
 # yum -y remove firewalld
```





Disable SELINUX on all nodes:

```
 # vi /etc/selinux/config

SELINUX=disabled
SELINUXTYPE=targeted 
```

OS update on all nodes, and reboot:
```
 # yum -y update ; reboot
```

Verify:
```
[kamran@kworkhorse ~]$ for i in etcd1 etcd2 controller1 controller2 worker1 worker2; do ssh root@${i} "hostname; getenforce"; done
etcd1.example.com
Disabled
etcd2.example.com
Disabled
controller1.example.com
Disabled
controller2.example.com
Disabled
worker1.example.com
Disabled
worker2.example.com
Disabled
[kamran@kworkhorse ~]$ 
```


# Configure / setup TLS certificates for the cluster:

Reference: [https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-certificate-authority.md](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/02-certificate-authority.md)


Before we start configuring various services on the nodes, we need to create the SSL/TLS certifcates, which will be used by the kubernetes components . Here I will setup a single certificate, but in production you are advised to create individual certificates for each component/service. We need to secure the following Kubernetes components:

* etcd
* Kubernetes API Server
* Kubernetes Kubelet


We will use CFSSL to create these certificates.

Linux:
```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl

wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```

## Create a Certificate Authority

### Create CA CSR config file:

```
echo '{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}' > ca-config.json
```

### Generate CA certificate and CA private key:

First, create a CSR  (Certificate Signing Request) for CA:

```
echo '{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Oslo",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oslo"
    }
  ]
}' > ca-csr.json
```


Now, generate CA certificate and it's private key:

```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

```
[kamran@kworkhorse certs-baremetal]$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
2016/09/08 11:32:54 [INFO] generating a new CA key and certificate from CSR
2016/09/08 11:32:54 [INFO] generate received request
2016/09/08 11:32:54 [INFO] received CSR
2016/09/08 11:32:54 [INFO] generating key: rsa-2048
2016/09/08 11:32:54 [INFO] encoded CSR
2016/09/08 11:32:54 [INFO] signed certificate with serial number 161389974620705926236327234344288710670396137404
[kamran@kworkhorse certs-baremetal]$ 
```

This should give you the following files:

```
ca.pem
ca-key.pem
ca.csr
```

In the list of generated files above, **ca.pem** is your CA certificate, **ca-key.pem** is the CA-certificate's private key, and **ca.csr** is the certificate signing request for this certificate.


You can verify that you have a certificate, by using the command below:

```
openssl x509 -in ca.pem -text -noout
```

It should give you the output similar to what is shown below:

```
[kamran@kworkhorse certs-baremetal]$ openssl x509 -in ca.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            1c:44:fa:0c:9d:6f:5b:66:03:cc:ac:f7:fe:b0:be:65:ab:73:9f:bc
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Validity
            Not Before: Sep  8 09:28:00 2016 GMT
            Not After : Sep  7 09:28:00 2021 GMT
        Subject: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c4:60:18:aa:dd:71:98:00:79:63:ee:31:82:11:
                    db:26:fb:f1:74:47:7b:85:f4:b0:cf:b2:d7:ce:59:
                    26:b6:f0:01:ea:4a:b1:a0:53:ae:45:51:1c:2a:98:
                    55:00:a5:1c:07:6b:96:f9:26:84:6e:0e:23:20:07:
                    85:6a:3c:a7:9c:be:f1:b6:95:d9:6a:68:be:70:7d:
                    6b:31:c6:78:80:78:27:ed:77:f2:ef:71:3b:6b:2d:
                    66:5f:ce:71:46:16:0f:b9:e7:55:a6:e3:03:75:c4:
                    17:59:7d:61:b1:84:19:06:8d:90:0d:d9:cb:ee:72:
                    cd:a2:7f:4e:ed:37:53:fc:cc:e4:12:b8:49:ad:bf:
                    f2:0f:79:60:ea:08:9b:ed:9c:65:f8:9b:8a:81:b5:
                    cc:1e:24:bd:9c:a9:fe:68:fa:49:73:cf:b4:aa:69:
                    1c:b1:e3:6b:a5:67:89:15:e8:e1:69:af:f9:b4:4b:
                    c1:b8:33:fe:82:54:a7:fd:24:3b:18:3d:91:98:7a:
                    e5:40:0d:1a:d2:4e:1c:38:12:c4:b9:8a:7e:54:8e:
                    fe:b2:93:01:be:99:aa:18:5c:50:24:68:03:87:ec:
                    58:35:08:94:5b:b4:00:db:58:0d:e9:0f:5e:80:66:
                    c7:8b:24:bd:4b:6d:31:9c:6f:b3:a2:0c:20:bb:3b:
                    da:b1
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:2
            X509v3 Subject Key Identifier: 
                9F:0F:21:A2:F0:F1:FF:C9:19:BE:5F:4C:30:73:FD:9C:A6:C1:A0:3C
            X509v3 Authority Key Identifier: 
                keyid:9F:0F:21:A2:F0:F1:FF:C9:19:BE:5F:4C:30:73:FD:9C:A6:C1:A0:3C

    Signature Algorithm: sha256WithRSAEncryption
         0b:e0:60:9d:5c:3e:95:50:aa:6d:56:2b:83:90:83:fe:81:34:
         f2:64:e1:2d:56:13:9a:ec:13:cb:d0:fc:2f:82:3e:24:86:25:
         73:5a:79:d3:07:76:4e:0b:2e:7c:56:7e:82:e1:6e:8f:89:94:
         61:5d:20:76:31:4c:a6:f0:ad:bc:73:49:d9:81:9c:1f:6f:ad:
         ea:fd:8c:4a:c5:9c:f9:77:0a:76:c3:b7:b4:b7:dc:d4:4d:3c:
         5a:47:d6:d7:fa:07:30:34:3b:f4:4c:59:1f:4e:15:e8:11:b6:
         b6:83:61:28:a9:86:70:f9:72:cd:91:2d:c3:d6:87:37:83:04:
         74:e2:ff:67:3d:ef:bf:3b:67:88:a9:64:2b:41:72:d5:34:e5:
         93:52:2e:4a:d5:6b:8d:8c:b3:66:fa:32:18:e0:5f:9e:f1:68:
         dc:51:81:52:dc:bc:8f:01:b5:22:92:d5:5e:1c:1c:f0:a3:ab:
         a8:c5:9d:84:60:80:e4:82:52:09:1a:1c:8d:1b:af:f9:a5:66:
         06:9a:fe:f4:b1:5f:6e:51:de:49:1f:07:eb:05:3f:f1:39:cc:
         29:aa:67:b0:e6:4a:6a:dd:14:6f:41:8d:67:f7:4b:55:99:49:
         3c:4f:56:5e:a5:dd:6c:7b:2c:23:32:ee:a1:d2:0a:d4:dd:b7:
         28:86:b4:42
[kamran@kworkhorse certs-baremetal]$ 
```

## Generate the single Kubernetes TLS certificate:
**Reminder:** We will generate a TLS certificate that will be valid for all Kubernetes components. This is being done for ease of use. In production you should strongly consider generating individual TLS certificates for each component.

We should also setup an environment variable named `KUBERNETES_PUBLIC_IP_ADDRESS` with the value `10.240.0.20` . This will be handy in the next step.

```
export KUBERNETES_PUBLIC_IP_ADDRESS='10.240.0.20'
```

### Create Kubernetes certificate CSR config file:

Be careful in creating this file. Make sure you use all the possible hostnames of the nodes you are generating this certificate for. This includes their FQDNs. When you setup node names like "nodename.example.com" then you need to include that in the CSR config file below. Also add a few extra entries for worker nodes, as you might want to increase the number of worker nodes later in this setup. So even though I have only two worker nodes right now, I have added two extra in the certificate below, worker 3 and 4. The hostnames controller.example.com and kubernetes.example.com are supposed to point to the VIP (10.240.0.20) of the controller nodes. All of these has to go into the infrastructure DNS.

**Note:** Kelsey's guide set "CN" to be "kubernetes", whereas I set it to "*.example.com" . See: [https://cabforum.org/information-for-site-owners-and-administrators/](https://cabforum.org/information-for-site-owners-and-administrators/)

```
cat > kubernetes-csr.json <<EOF
{
  "CN": "*.example.com",
  "hosts": [
    "10.32.0.1",
    "etcd1",
    "etcd2",
    "etcd1.example.com",
    "etcd2.example.com",
    "10.240.0.11",
    "10.240.0.12",
    "controller1",
    "controller2",
    "controller1.example.com",
    "controller2.example.com",
    "10.240.0.21",
    "10.240.0.22",
    "worker1",
    "worker2",
    "worker3",
    "worker4",
    "worker1.example.com",
    "worker2.example.com",
    "worker3.example.com",
    "worker4.example.com",
    "10.240.0.31",
    "10.240.0.32",
    "10.240.0.33",
    "10.240.0.34",
    "controller.example.com",
    "kubernetes.example.com",
    "${KUBERNETES_PUBLIC_IP_ADDRESS}",
    "localhost",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NO",
      "L": "Oslo",
      "O": "Kubernetes",
      "OU": "Cluster",
      "ST": "Oslo"
    }
  ]
}
EOF
```

### Generate the Kubernetes certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```

```
[kamran@kworkhorse certs-baremetal]$ cfssl gencert \
>   -ca=ca.pem \
>   -ca-key=ca-key.pem \
>   -config=ca-config.json \
>   -profile=kubernetes \
>   kubernetes-csr.json | cfssljson -bare kubernetes
2016/09/08 14:04:04 [INFO] generate received request
2016/09/08 14:04:04 [INFO] received CSR
2016/09/08 14:04:04 [INFO] generating key: rsa-2048
2016/09/08 14:04:04 [INFO] encoded CSR
2016/09/08 14:04:04 [INFO] signed certificate with serial number 448428141554905058774798041748928773753703785287
2016/09/08 14:04:04 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[kamran@kworkhorse certs-baremetal]$
```

After you execute the above code, you get the following additional files:

```
kubernetes-csr.json
kubernetes-key.pem
kubernetes.pem
```

Verify the contents of the generated certificate:

```
openssl x509 -in kubernetes.pem -text -noout
```


```
[kamran@kworkhorse certs-baremetal]$ openssl x509 -in kubernetes.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            72:f8:47:b0:9c:ff:4e:f1:4e:3a:0d:5c:e9:f9:77:e9:7d:85:fd:ae
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Validity
            Not Before: Sep  9 08:26:00 2016 GMT
            Not After : Sep  9 08:26:00 2017 GMT
        Subject: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=Cluster, CN=*.example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:e8:c4:01:e6:06:79:6b:b1:00:ec:7a:d4:c9:86:
                    77:f7:b2:e5:c6:e5:c8:6a:65:a1:89:d6:f6:66:09:
                    26:c3:9d:bd:39:2d:ee:eb:a8:88:d7:d9:85:3e:bf:
                    82:e0:34:83:68:70:33:6a:61:ae:c9:93:69:75:06:
                    57:da:a8:47:39:89:e1:a7:e8:72:27:89:46:6d:df:
                    fe:ed:75:99:f5:74:f0:28:22:05:f5:ac:83:af:2e:
                    e9:e0:79:0d:9b:a6:7e:71:78:90:b2:a0:14:54:92:
                    66:c1:16:e9:a2:9a:a8:4d:fb:ba:c3:22:d8:e1:f3:
                    d5:38:97:08:2b:d5:ec:1f:ba:01:9f:02:e5:7e:c9:
                    a2:a8:2d:b3:ba:33:ba:f0:61:da:ff:1a:e8:1f:61:
                    f9:1b:42:eb:f8:be:52:bf:5e:56:7d:7e:85:f7:8b:
                    01:2f:e5:c9:56:53:af:b4:87:e8:44:e2:8f:09:bf:
                    6e:85:42:4d:cb:7a:f9:f4:03:85:3f:af:b7:2e:d5:
                    58:c0:1c:62:2b:fc:b8:b7:b7:b9:d3:d3:6f:82:19:
                    89:dc:df:d9:f3:43:13:e5:e0:04:f4:8d:ce:b0:98:
                    88:81:b5:96:bb:a2:cf:90:86:f4:16:6a:34:3d:c6:
                    f7:a1:e1:2c:d4:3f:c0:b5:32:70:c1:77:2e:17:20:
                    7e:7b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier: 
                A4:9B:A2:1A:F4:AF:71:A6:2F:C7:8B:BE:83:7B:A0:DB:D3:70:91:12
            X509v3 Authority Key Identifier: 
                keyid:9F:0F:21:A2:F0:F1:FF:C9:19:BE:5F:4C:30:73:FD:9C:A6:C1:A0:3C

            X509v3 Subject Alternative Name: 
                DNS:etcd1, DNS:etcd2, DNS:etcd1.example.com, DNS:etcd2.example.com, DNS:controller1, DNS:controller2, DNS:controller1.example.com, DNS:controller2.example.com, DNS:worker1, DNS:worker2, DNS:worker3, DNS:worker4, DNS:worker1.example.com, DNS:worker2.example.com, DNS:worker3.example.com, DNS:worker4.example.com, DNS:controller.example.com, DNS:kubernetes.example.com, DNS:localhost, IP Address:10.32.0.1, IP Address:10.240.0.11, IP Address:10.240.0.12, IP Address:10.240.0.21, IP Address:10.240.0.22, IP Address:10.240.0.31, IP Address:10.240.0.32, IP Address:10.240.0.33, IP Address:10.240.0.34, IP Address:10.240.0.20, IP Address:127.0.0.1
    Signature Algorithm: sha256WithRSAEncryption
         5f:5f:cd:b0:0f:f6:7e:9d:6d:8b:ba:38:09:18:66:24:8b:4b:
         5b:71:0a:a2:b4:36:79:ae:99:5a:9b:38:07:89:05:90:53:ee:
         8c:e5:52:c9:ef:8e:1a:97:62:e7:a7:c5:70:06:6f:39:30:ba:
         32:dd:9f:72:c7:d3:09:82:4a:b6:2c:80:35:ec:e2:8f:97:dd:
         e6:34:e9:27:e6:e0:2a:9d:d9:42:94:a5:45:fe:d0:b2:30:88:
         1f:b1:5e:1c:91:a2:53:f8:6b:ad:2e:ae:b3:8a:4b:fe:aa:97:
         7d:65:2a:39:02:f8:a0:28:e8:d2:d0:bf:fb:1b:4f:57:9c:3f:
         bf:78:07:0b:c9:67:12:48:63:a2:f0:59:ff:8b:a2:10:26:d3:
         3a:0b:c3:73:85:2e:ee:14:ea:2f:1e:30:fb:78:b6:79:c9:6c:
         76:f1:fe:02:26:13:69:7c:27:74:31:21:c6:43:b5:b3:17:94:
         ed:ab:b2:05:fe:07:90:8d:6f:38:67:dc:34:6a:2d:5b:1e:f1:
         2b:b4:17:88:d6:9d:b3:0a:86:d4:0a:ad:c2:a3:bf:19:8c:99:
         74:73:be:b0:65:da:b9:cf:78:e6:14:64:ce:04:0e:48:8d:c9:
         16:c0:c7:8f:9e:9f:66:85:e6:c8:13:2e:73:20:22:35:db:ef:
         0b:cf:b6:03
[kamran@kworkhorse certs-baremetal]$ 
```

## Copy the certificates to the nodes:

```
[kamran@kworkhorse certs-baremetal]$ for i in etcd1 etcd2 controller1 controller2 worker1 worker2; do scp ca.pem kubernetes-key.pem kubernetes.pem  root@${i}:/root/ ; done
ca.pem                                                                                                        100% 1350     1.3KB/s   00:00    
kubernetes-key.pem                                                                                            100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                100% 1927     1.9KB/s   00:00    
ca.pem                                                                                                        100% 1350     1.3KB/s   00:00    
kubernetes-key.pem                                                                                            100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                100% 1927     1.9KB/s   00:00    
ca.pem                                                                                                        100% 1350     1.3KB/s   00:00    
kubernetes-key.pem                                                                                            100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                100% 1927     1.9KB/s   00:00    
ca.pem                                                                                                        100% 1350     1.3KB/s   00:00    
kubernetes-key.pem                                                                                            100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                100% 1927     1.9KB/s   00:00    
ca.pem                                                                                                        100% 1350     1.3KB/s   00:00    
kubernetes-key.pem                                                                                            100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                100% 1927     1.9KB/s   00:00    
ca.pem                                                                                                        100% 1350     1.3KB/s   00:00    
kubernetes-key.pem                                                                                            100% 1679     1.6KB/s   00:00    
kubernetes.pem                                                                                                100% 1927     1.9KB/s   00:00    
[kamran@kworkhorse certs-baremetal]$ 
```


# Configure etcd nodes:

The reason of having dedicated etcd nodes, as explained by Kelsey:

All Kubernetes components are stateless which greatly simplifies managing a Kubernetes cluster. All state is stored in etcd, which is a database and must be treated special. etcd is being run on a dedicated set of machines for the following reasons:

* The etcd lifecycle is not tied to Kubernetes. We should be able to upgrade etcd independently of Kubernetes.
* Scaling out etcd is different than scaling out the Kubernetes Control Plane.
* Prevent other applications from taking up resources (CPU, Memory, I/O) required by etcd.

First, move the certificates in place.

```
[root@etcd1 ~]# sudo mkdir -p /etc/etcd/
[root@etcd1 ~]# ls /etc/etcd/
[root@etcd1 ~]# sudo mv ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
```



Then, install necessary software on etcd nodes. Remember that the etcd version which comes with Fedora 24 is 2.2, whereas the latest version of etcd available on it's github page is 3.0.7 . So we download and install that one.

Do the following steps on both nodes:
```
curl -L https://github.com/coreos/etcd/releases/download/v3.0.7/etcd-v3.0.7-linux-amd64.tar.gz -o etcd-v3.0.7-linux-amd64.tar.gz
tar xzvf etcd-v3.0.7-linux-amd64.tar.gz 
sudo cp etcd-v3.0.7-linux-amd64/etcd* /usr/bin/
sudo mkdir -p /var/lib/etcd
```

Create the etcd systemd unit file:

```
cat > etcd.service <<"EOF"
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/bin/etcd --name ETCD_NAME \
  --cert-file=/etc/etcd/kubernetes.pem \
  --key-file=/etc/etcd/kubernetes-key.pem \
  --peer-cert-file=/etc/etcd/kubernetes.pem \
  --peer-key-file=/etc/etcd/kubernetes-key.pem \
  --trusted-ca-file=/etc/etcd/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ca.pem \
  --initial-advertise-peer-urls https://INTERNAL_IP:2380 \
  --listen-peer-urls https://INTERNAL_IP:2380 \
  --listen-client-urls https://INTERNAL_IP:2379,http://127.0.0.1:2379 \
  --advertise-client-urls https://INTERNAL_IP:2379 \
  --initial-cluster-token etcd-cluster-0 \
  --initial-cluster etcd1=https://10.240.0.11:2380,etcd2=https://10.240.0.12:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```



**Note:** Make sure to change the IP below to the one belonging to the etcd node you are configuring.
```
export INTERNAL_IP='10.240.0.11'
export ETCD_NAME=$(hostname -s)
sed -i s/INTERNAL_IP/$INTERNAL_IP/g etcd.service
sed -i s/ETCD_NAME/$ETCD_NAME/g etcd.service
sudo mv etcd.service /etc/systemd/system/
```

Start etcd:
```
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```



## Verify that etcd is running:
```
[root@etcd1 ~]# sudo systemctl status etcd --no-pager
● etcd.service - etcd
   Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-09-09 11:12:05 CEST; 29s ago
     Docs: https://github.com/coreos
 Main PID: 1563 (etcd)
    Tasks: 6 (limit: 512)
   CGroup: /system.slice/etcd.service
           └─1563 /usr/bin/etcd --name etcd1 --cert-file=/etc/etcd/kubernetes.pem --key-file=/etc/etcd/kubernetes-key.pem --peer-cert-file=/e...

Sep 09 11:12:32 etcd1.example.com etcd[1563]: ffed16798470cab5 [logterm: 1, index: 2] sent vote request to 3a57933972cb5131 at term 20
Sep 09 11:12:33 etcd1.example.com etcd[1563]: ffed16798470cab5 is starting a new election at term 20
Sep 09 11:12:33 etcd1.example.com etcd[1563]: ffed16798470cab5 became candidate at term 21
Sep 09 11:12:33 etcd1.example.com etcd[1563]: ffed16798470cab5 received vote from ffed16798470cab5 at term 21
Sep 09 11:12:33 etcd1.example.com etcd[1563]: ffed16798470cab5 [logterm: 1, index: 2] sent vote request to 3a57933972cb5131 at term 21
Sep 09 11:12:34 etcd1.example.com etcd[1563]: publish error: etcdserver: request timed out
Sep 09 11:12:35 etcd1.example.com etcd[1563]: ffed16798470cab5 is starting a new election at term 21
Sep 09 11:12:35 etcd1.example.com etcd[1563]: ffed16798470cab5 became candidate at term 22
Sep 09 11:12:35 etcd1.example.com etcd[1563]: ffed16798470cab5 received vote from ffed16798470cab5 at term 22
Sep 09 11:12:35 etcd1.example.com etcd[1563]: ffed16798470cab5 [logterm: 1, index: 2] sent vote request to 3a57933972cb5131 at term 22
[root@etcd1 ~]# 


[root@etcd1 ~]# netstat -ntlp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 10.240.0.11:2379        0.0.0.0:*               LISTEN      1563/etcd           
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      1563/etcd           
tcp        0      0 10.240.0.11:2380        0.0.0.0:*               LISTEN      1563/etcd           
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      591/sshd            
tcp6       0      0 :::9090                 :::*                    LISTEN      1/systemd           
tcp6       0      0 :::22                   :::*                    LISTEN      591/sshd            
[root@etcd1 ~]# 

[root@etcd1 ~]# etcdctl --ca-file=/etc/etcd/ca.pem cluster-health
cluster may be unhealthy: failed to list members
Error:  client: etcd cluster is unavailable or misconfigured
error #0: client: endpoint http://127.0.0.1:2379 exceeded header timeout
error #1: dial tcp 127.0.0.1:4001: getsockopt: connection refused

[root@etcd1 ~]# 
```

**Note:** When there is only one node, the etcd cluster will show up as unavailable or misconfigured.


## Verify:

After executing all the steps on etcd2 too, I have the following status of services on etcd2:
```
[root@etcd2 ~]# systemctl status etcd
● etcd.service - etcd
   Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-09-09 11:26:15 CEST; 5s ago
     Docs: https://github.com/coreos
 Main PID: 2210 (etcd)
    Tasks: 7 (limit: 512)
   CGroup: /system.slice/etcd.service
           └─2210 /usr/bin/etcd --name etcd2 --cert-file=/etc/etcd/kubernetes.pem --key-file=/etc/etcd/kubernetes-key.pem --peer-cert-file=/etc/

Sep 09 11:26:16 etcd2.example.com etcd[2210]: 3a57933972cb5131 [logterm: 1, index: 2, vote: 0] voted for ffed16798470cab5 [logterm: 1, index: 2]
Sep 09 11:26:16 etcd2.example.com etcd[2210]: raft.node: 3a57933972cb5131 elected leader ffed16798470cab5 at term 587
Sep 09 11:26:16 etcd2.example.com etcd[2210]: published {Name:etcd2 ClientURLs:[https://10.240.0.12:2379]} to cluster cdeaba18114f0e16
Sep 09 11:26:16 etcd2.example.com etcd[2210]: ready to serve client requests
Sep 09 11:26:16 etcd2.example.com etcd[2210]: serving insecure client requests on 127.0.0.1:2379, this is strongly discouraged!
Sep 09 11:26:16 etcd2.example.com etcd[2210]: forgot to set Type=notify in systemd service file?
Sep 09 11:26:16 etcd2.example.com etcd[2210]: ready to serve client requests
Sep 09 11:26:16 etcd2.example.com etcd[2210]: serving client requests on 10.240.0.12:2379
Sep 09 11:26:16 etcd2.example.com etcd[2210]: set the initial cluster version to 3.0
Sep 09 11:26:16 etcd2.example.com etcd[2210]: enabled capabilities for version 3.0
lines 1-19/19 (END)
```

```
[root@etcd2 ~]# netstat -antlp 
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 10.240.0.12:2379        0.0.0.0:*               LISTEN      2210/etcd           
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      2210/etcd           
tcp        0      0 10.240.0.12:2380        0.0.0.0:*               LISTEN      2210/etcd           
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      592/sshd            
tcp        0      0 127.0.0.1:40780         127.0.0.1:2379          ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2379        10.240.0.12:35998       ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:2379          127.0.0.1:40780         ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:34986       10.240.0.11:2380        ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:35998       10.240.0.12:2379        ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2379        10.240.0.12:36002       ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:40784         127.0.0.1:2379          ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2379        10.240.0.12:35996       ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2379        10.240.0.12:35994       ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:36002       10.240.0.12:2379        ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:2379          127.0.0.1:40788         ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:36004       10.240.0.12:2379        ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:35994       10.240.0.12:2379        ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:2379          127.0.0.1:40782         ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2380        10.240.0.11:37048       ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2380        10.240.0.11:37050       ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2380        10.240.0.11:37046       ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:40782         127.0.0.1:2379          ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:35996       10.240.0.12:2379        ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2380        10.240.0.11:37076       ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:40786         127.0.0.1:2379          ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:2379          127.0.0.1:40790         ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:34988       10.240.0.11:2380        ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2379        10.240.0.12:36000       ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:40788         127.0.0.1:2379          ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:2379          127.0.0.1:40784         ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:22          10.240.0.1:51040        ESTABLISHED 1796/sshd: root [pr 
tcp        0      0 10.240.0.12:35014       10.240.0.11:2380        ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:2379          127.0.0.1:40786         ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:36000       10.240.0.12:2379        ESTABLISHED 2210/etcd           
tcp        0      0 127.0.0.1:40790         127.0.0.1:2379          ESTABLISHED 2210/etcd           
tcp        0      0 10.240.0.12:2379        10.240.0.12:36004       ESTABLISHED 2210/etcd           
tcp6       0      0 :::9090                 :::*                    LISTEN      1/systemd           
tcp6       0      0 :::22                   :::*                    LISTEN      592/sshd            
[root@etcd2 ~]#
```


```
[root@etcd2 ~]# etcdctl --ca-file=/etc/etcd/ca.pem cluster-health
member 3a57933972cb5131 is healthy: got healthy result from https://10.240.0.12:2379
member ffed16798470cab5 is healthy: got healthy result from https://10.240.0.11:2379
cluster is healthy
[root@etcd2 ~]# 
```

```
[root@etcd1 ~]# etcdctl --ca-file=/etc/etcd/ca.pem cluster-health
member 3a57933972cb5131 is healthy: got healthy result from https://10.240.0.12:2379
member ffed16798470cab5 is healthy: got healthy result from https://10.240.0.11:2379
cluster is healthy
[root@etcd1 ~]# 
```





