# Kubernetes - The hard way - on AWS

# Summary
This document is an attempt to create a Kubernetes cluster, the same way as one would build on GCE. You can check this document here: [Kubernetes-The-Hard-Way-on-GCE.md](Kubernetes-The-Hard-Way-on-GCE.md) , if you want a reference.

The idea is to also include a LoadBalancer which we (Praqma) built especially for Kubernetes. I will also try to setup an internal load balancer for Kubernetes Master/Controller nodes, something which I did not do (nor Kelsey did) while setting up Kubernetes on GCE.

This setup will also introduce High Availability for etcd and master/controller nodes.

I am not using AWS command line utility. Everything I do here is by using AWS web interface. Though, using AWS CLI is much faster.

The OS used on all the nodes is Fedora Atomic 24 64 bit. Exception: The controller nodes are Fedora Cloud Base , not Fedora Atomic. It is because Fedora Atomic does not let us manage individual packages, and we needed latest Kubernetes 1.3 to work with the way we want it to work, especially with CIDR. Fedora Cloud Base is minimal Fedora and you can add packages on top of it. For more information and differences between different types of Fedora OS, look here: [http://fedoracloud.readthedocs.io/en/latest/whatis.html](http://fedoracloud.readthedocs.io/en/latest/whatis.html)

Also, note that we can manage AWS VPC's router and add routes of our nodes. Ideally we should not need flannel.

# Network setup

I have created a new VPC on AWS with a base network address of 10.0.0.0/16 .
This VPC has a public subnet inside it with a network address of 10.0.0.0/24 . All the nodes are created in this (so called - public) network.

There are 6 nodes in total for main Kubernetes functionality, with the following IP addresses:

* etcd1 - 54.93.98.33 - 10.0.0.245
* etcd2 - 54.93.95.206 - 10.0.0.246
* controller1 - 54.93.35.52 - 10.0.0.137
* controller2 - 54.93.88.77 - 10.0.0.138
* worker1 - 52.59.249.129 - 10.0.0.181
* worker2 - 54.93.34.227 - 10.0.0.182

Note: Kelsey's howto has the IP addresses in the range 10.240.0.* . So if you are following that (or using it as a reference), it is good to know what are the differences between his documentation and ours.

Cluster / Service IPs: 10.32.0.0/24 ( not configured on any interaface of any node). 
Cluster CIDR (like flannel network) = 10.200.0.0/16 (each node will get a subnet out of this network space to use for containers). This is same as Kelseys howto.

I will use the same /etc/hosts on all nodes, so I do not have to keep track of the IP addresses in various config files.



The /etc/hosts file I am using is:
```
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
10.0.0.245	etcd1
10.0.0.246	etcd2
10.0.0.137	controller1
10.0.0.138	controller2
10.0.0.181	worker1
10.0.0.182	worker2
```

** Note: ** When you edit the hosts file to all nodes, also use that time to disable SELINUX on all nodes, to save pain and grief later.


On AWS Firewall/Security group, I have allowed all traffic within this VPC from 10.0.0.0/16. Also all traffic is allowed from my IP.

# Reserve a public IP address for Kubernetes control plane, to be used from the outside world to connect to Kubernetes

Here you create a public IP address which will be used as a frontend for kubernetes control plane. We need to do this before the generation of SSL certificates, because we are going to use that IP address in the certificates.

Create a new Elastic IP. You do not need to assign this IP to any instance at the moment.
IP = 52.59.74.90





# Setup Certificate Authority and Generate TLS certificates
On local work computer. 

We will use CFSSL (why? Todo)

## Install CFSSL

On work computer.

```
wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
chmod +x cfssl_linux-amd64
sudo mv cfssl_linux-amd64 /usr/local/bin/cfssl


wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x cfssljson_linux-amd64
sudo mv cfssljson_linux-amd64 /usr/local/bin/cfssljson
```

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

```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca


[kamran@kworkhorse ~]$ cfssl gencert -initca ca-csr.json | cfssljson -bare ca
2016/07/13 13:17:32 [INFO] generating a new CA key and certificate from CSR
2016/07/13 13:17:32 [INFO] generate received request
2016/07/13 13:17:32 [INFO] received CSR
2016/07/13 13:17:32 [INFO] generating key: rsa-2048
2016/07/13 13:17:32 [INFO] encoded CSR
2016/07/13 13:17:32 [INFO] signed certificate with serial number 58822608155516168535438893668485299792393775635
[kamran@kworkhorse ~]$ 
```

Resulting files:
```
[kamran@kworkhorse ~]$ ls -ltrh
-rw-rw-r--  1 kamran kamran  232 Jul 13 13:15 ca-config.json
-rw-rw-r--  1 kamran kamran  205 Jul 13 13:17 ca-csr.json
-rw-rw-r--  1 kamran kamran 1.4K Jul 13 13:17 ca.pem
-rw-------  1 kamran kamran 1.7K Jul 13 13:17 ca-key.pem
-rw-r--r--  1 kamran kamran  997 Jul 13 13:17 ca.csr
[kamran@kworkhorse ~]$ 
```

Validate:
```
[kamran@kworkhorse ~]$ openssl x509 -in ca.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            0a:4d:b2:6c:f7:f6:8a:c4:7c:d4:8e:86:d3:93:60:05:b2:43:aa:13
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Validity
            Not Before: Jul 13 11:13:00 2016 GMT
            Not After : Jul 12 11:13:00 2021 GMT
        Subject: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:c6:5e:6e:c7:2f:4b:d7:15:a8:80:a5:98:73:05:
                    1b:fe:f2:0a:f5:04:6d:fd:1f:ac:b1:61:13:9a:1e:
                    ff:27:26:6e:3a:d1:07:a7:db:c6:4e:78:7f:0c:13:
                    21:a2:22:43:b2:23:48:ce:5b:56:60:d7:04:b6:ff:
                    fa:e5:a7:d3:65:c9:7f:c2:65:f3:96:75:56:c0:02:
                    17:84:50:8e:7a:ac:e3:4c:ce:1c:d1:da:e5:7c:4d:
                    a8:16:39:ca:5f:2f:8f:45:cb:b3:1b:71:4d:a6:27:
                    a7:bd:6b:0a:52:dd:7f:dc:7a:62:56:38:48:0a:e4:
                    26:32:38:a7:70:1f:08:25:d4:b3:00:82:88:f0:4d:
                    c5:40:67:df:4d:a9:5a:be:38:4a:3f:6c:a1:7c:18:
                    d6:43:a6:ae:3d:f1:df:85:e2:d9:08:97:93:ed:2c:
                    37:7a:53:13:ef:34:83:6f:0f:7c:99:2c:b2:b7:dc:
                    6e:04:38:d1:6a:43:b0:0f:74:c7:e0:bf:30:78:d9:
                    58:36:b6:44:5a:22:0f:34:60:4d:ce:d5:86:02:de:
                    0a:94:65:3d:61:d6:82:3b:c4:fb:1b:4b:05:21:1c:
                    4a:0f:e7:e7:20:f6:e6:27:8f:f3:84:66:86:df:e2:
                    c9:f3:8e:96:25:7b:23:b1:13:c9:c2:e1:03:06:17:
                    17:15
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Certificate Sign, CRL Sign
            X509v3 Basic Constraints: critical
                CA:TRUE, pathlen:2
            X509v3 Subject Key Identifier: 
                43:B4:D8:70:0A:43:2B:61:A7:22:ED:54:69:15:D2:04:46:93:3E:E5
            X509v3 Authority Key Identifier: 
                keyid:43:B4:D8:70:0A:43:2B:61:A7:22:ED:54:69:15:D2:04:46:93:3E:E5

    Signature Algorithm: sha256WithRSAEncryption
         4c:97:9c:94:d3:04:81:f4:88:d4:38:64:d9:0e:2a:b9:27:a4:
         10:48:b9:14:34:6c:50:27:b8:ec:6d:0f:cd:11:dd:8b:3c:1f:
         95:79:49:89:b1:ea:90:6c:66:52:18:8e:ff:34:d8:f5:be:04:
         ae:df:db:f8:ca:c9:4f:58:8e:28:20:93:22:2a:db:bc:72:3c:
         2a:52:10:85:8f:f7:e4:77:fa:94:d2:d5:fb:33:83:0f:3d:a3:
         d6:0b:68:5f:35:06:c9:ff:10:d4:cb:c8:31:3e:37:a8:45:46:
         07:fd:75:de:59:aa:47:a8:fd:42:22:57:93:ab:aa:12:8b:1c:
         b0:4b:19:15:58:f4:97:43:70:fc:ce:d6:a8:16:28:fe:51:db:
         b2:76:d5:2c:ec:01:94:f3:2d:67:8f:55:dc:be:f3:ef:a9:5b:
         c8:2d:74:2e:7a:1b:67:9d:63:39:39:0d:14:d8:77:59:26:fc:
         02:c7:cd:52:22:25:83:74:4e:98:1f:0d:32:32:64:ed:5a:07:
         1a:e7:dc:0e:85:48:aa:bf:b8:9b:41:17:0d:a9:a9:98:34:8c:
         1c:25:f7:4c:dd:ca:1b:36:86:7f:90:53:25:5a:6c:d8:2e:5c:
         3d:a4:be:e8:d2:a3:d0:2c:9b:ca:7c:0a:1f:43:48:1d:9e:7a:
         9b:64:31:6f
[kamran@kworkhorse ~]$ 
```


## Generate the single Kubernetes TLS Cert

```
export KUBERNETES_PUBLIC_IP_ADDRESS="52.59.74.90"

echo $KUBERNETES_PUBLIC_IP_ADDRESS
```


```
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "etcd1",
    "etcd2",
    "controller1",
    "controller2",
    "worker1",
    "worker2",
    "10.0.0.1",
    "10.0.0.245",
    "10.0.0.246",
    "10.0.0.137",
    "10.0.0.138",
    "10.0.0.181",
    "10.0.0.182",
    "${KUBERNETES_PUBLIC_IP_ADDRESS}",
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

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```

Actual run:
```
[kamran@kworkhorse ~]$ cfssl gencert   -ca=ca.pem   -ca-key=ca-key.pem   -config=ca-config.json   -profile=kubernetes   kubernetes-csr.json | cfssljson -bare kubernetes
2016/07/18 15:47:18 [INFO] generate received request
2016/07/18 15:47:18 [INFO] received CSR
2016/07/18 15:47:18 [INFO] generating key: rsa-2048
2016/07/18 15:47:18 [INFO] encoded CSR
2016/07/18 15:47:18 [INFO] signed certificate with serial number 724227408907546570849472486117745474266150945034
2016/07/18 15:47:18 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[kamran@kworkhorse ~]$ 
```

Todo: Why does the output say that it lacks a hosts field? 

Resulting files:
```
[kamran@kworkhorse ~]$ ls -ltrh
-rw-rw-r--  1 kamran kamran  232 Jul 13 13:15 ca-config.json
-rw-rw-r--  1 kamran kamran  205 Jul 13 13:17 ca-csr.json
-rw-rw-r--  1 kamran kamran 1.4K Jul 13 13:17 ca.pem
-rw-------  1 kamran kamran 1.7K Jul 13 13:17 ca-key.pem
-rw-r--r--  1 kamran kamran  997 Jul 13 13:17 ca.csr
-rw-rw-r--  1 kamran kamran  511 Jul 18 15:47 kubernetes-csr.json
-rw-rw-r--  1 kamran kamran 1.6K Jul 18 15:47 kubernetes.pem
-rw-------  1 kamran kamran 1.7K Jul 18 15:47 kubernetes-key.pem
-rw-r--r--  1 kamran kamran 1.2K Jul 18 15:47 kubernetes.csr
[kamran@kworkhorse ~]$ 
```

```
[kamran@kworkhorse ~]$ openssl x509 -in kubernetes.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            7e:db:7a:ed:b4:26:4f:06:19:b5:6e:64:c1:fc:f7:5a:1b:93:41:0a
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Validity
            Not Before: Jul 18 13:42:00 2016 GMT
            Not After : Jul 18 13:42:00 2017 GMT
        Subject: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=Cluster, CN=kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:9a:8e:e3:db:da:21:d4:31:2e:57:84:35:39:84:
                    26:8b:24:8b:be:98:d9:0f:ba:70:57:0f:5e:6e:71:
                    ac:01:6b:5e:4b:b9:73:d5:e6:d6:67:87:56:86:3f:
                    64:52:d7:d1:a5:4e:9d:10:95:bd:94:dc:a8:5c:f8:
                    b1:93:40:dc:89:0d:18:d6:a4:51:a8:ff:58:0b:d1:
                    63:9e:7a:a4:8c:9e:68:5f:b7:b1:dc:6e:3c:6c:94:
                    a4:59:77:79:1b:d6:4e:97:98:25:fd:e6:87:3f:63:
                    89:ce:b9:d1:62:74:23:06:50:aa:e4:09:2b:60:2f:
                    d6:2a:88:69:da:d2:90:28:61:f6:d1:11:b9:ef:aa:
                    5c:25:70:ae:f7:91:cf:34:ef:8c:5c:c1:96:83:e9:
                    35:c4:28:8d:bb:d8:cf:4a:f9:e8:88:9d:90:19:cc:
                    f8:6d:29:2c:48:6d:18:db:ca:95:be:2c:d8:30:d1:
                    06:b4:11:fe:a7:76:92:14:5f:bd:9f:dd:7b:7f:0f:
                    b5:79:76:db:6b:e7:fa:d0:fe:96:24:7c:1f:e7:3e:
                    51:13:c3:61:13:8d:a8:92:d7:32:a8:dc:34:d2:e1:
                    77:8c:27:ae:e3:b1:9d:d6:52:ff:e6:fd:2b:2d:05:
                    6d:ca:dc:1c:7c:8f:35:32:bc:0b:5b:82:19:69:00:
                    9f:df
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier: 
                C8:6C:FC:C6:BF:DF:39:63:DA:82:7C:22:A5:FF:B7:D8:F8:DE:17:F7
            X509v3 Authority Key Identifier: 
                keyid:43:B4:D8:70:0A:43:2B:61:A7:22:ED:54:69:15:D2:04:46:93:3E:E5

            X509v3 Subject Alternative Name: 
                DNS:etcd1, DNS:etcd2, DNS:controller1, DNS:controller2, DNS:worker1, DNS:worker2, IP Address:10.0.0.1, IP Address:10.0.0.245, IP Address:10.0.0.246, IP Address:10.0.0.137, IP Address:10.0.0.138, IP Address:10.0.0.181, IP Address:10.0.0.182, IP Address:52.59.74.90, IP Address:127.0.0.1
    Signature Algorithm: sha256WithRSAEncryption
         c2:5e:a7:e2:a6:b0:50:30:2b:53:dd:b5:8b:41:78:83:00:d2:
         59:03:18:79:d6:75:78:78:cb:e9:de:32:3a:5c:74:90:18:39:
         e1:4b:70:b2:e8:0f:4c:ae:ca:12:06:48:55:a1:3d:e3:dc:1c:
         fb:aa:d7:c5:85:74:29:41:62:2b:55:4f:ff:77:33:4e:b0:32:
         b6:6a:ea:fa:c0:e4:3b:ce:11:2d:b4:64:b2:c2:23:e2:2a:97:
         a8:ed:7d:28:dc:0d:2c:74:8f:7c:a4:09:66:5c:d4:ce:33:ec:
         2d:cb:a5:38:4b:c8:b4:fb:79:90:ed:58:b5:0d:9a:22:16:1c:
         cf:1c:1d:49:12:4a:bd:f5:14:66:4b:51:5f:96:95:f0:81:e5:
         31:9b:a6:3f:4e:4d:71:42:1c:99:33:e5:0f:87:57:0b:e7:23:
         5e:8b:e5:96:4f:99:ca:e8:95:4c:bd:fa:a7:44:e8:cb:6c:55:
         60:b8:bd:73:be:7a:c8:13:0c:78:d6:6e:24:79:28:4a:d9:97:
         05:e3:9c:4a:5d:a1:a7:80:91:11:19:de:ab:4a:6a:f5:6c:94:
         0e:39:30:14:65:7b:34:a8:08:30:2e:1b:56:19:4c:31:10:39:
         6f:94:e5:df:6a:4c:86:47:c9:58:aa:9a:bc:08:2c:8f:76:23:
         4f:c9:fa:9f
[kamran@kworkhorse ~]$ 
```

Copy TLS Certs to proper locations in respective nodes:
```
[kamran@kworkhorse ~]$ scp -i Downloads/Kamran-AWS.pem  ca.pem kubernetes-key.pem kubernetes.pem  fedora@etcd1:~/
[kamran@kworkhorse ~]$ scp -i Downloads/Kamran-AWS.pem  ca.pem kubernetes-key.pem kubernetes.pem  fedora@etcd2:~/
[kamran@kworkhorse ~]$ scp -i Downloads/Kamran-AWS.pem  ca.pem kubernetes-key.pem kubernetes.pem  fedora@controller1:~/
[kamran@kworkhorse ~]$ scp -i Downloads/Kamran-AWS.pem  ca.pem kubernetes-key.pem kubernetes.pem  fedora@controller2:~/
[kamran@kworkhorse ~]$ scp -i Downloads/Kamran-AWS.pem  ca.pem kubernetes-key.pem kubernetes.pem  fedora@worker1:~/
[kamran@kworkhorse ~]$ scp -i Downloads/Kamran-AWS.pem  ca.pem kubernetes-key.pem kubernetes.pem  fedora@worker2:~/
```

# Setup HA etcd cluster:

Run the following commands on etcd1, etcd2:

SSH into each machine using ssh command. 

etcd software is already pre-installed on Fedora Atomic, we just need to configure it.

```
[kamran@kworkhorse ~]$ ssh -i Downloads/Kamran-AWS.pem fedora@etcd1
```

```
[fedora@ip-10-0-0-245 ~]$ sudo rpm -q etcd
etcd-2.2.5-5.fc24.x86_64
```


Copy the three certificate (.pem) files to etcd directory:
```
[fedora@ip-10-0-0-245 ~]$ sudo mv  /home/fedora/*.pem /etc/etcd/
```


Create the etcd systemd unit file (as it is - i.e. Do not replcace ETCD_NAME and INTERNAL_IP yet):
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
  --initial-cluster etcd1=https://10.0.0.245:2380,etcd2=https://10.0.0.246:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Now, set INTERNAL_IP and ETCD_NAME on the shell:
```
[fedora@ip-10-0-0-245 ~]$ INTERNAL_IP=10.0.0.245
[fedora@ip-10-0-0-245 ~]$ ETCD_NAME=etcd1

[fedora@ip-10-0-0-245 ~]$ echo $INTERNAL_IP 
10.0.0.245
[fedora@ip-10-0-0-245 ~]$ echo $ETCD_NAME 
etcd1
[fedora@ip-10-0-0-245 ~]$ 
```

Adjust the service will with this values using sed , and move the service file to proper location:

```
[fedora@ip-10-0-0-245 ~]$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g etcd.service
[fedora@ip-10-0-0-245 ~]$ sed -i s/ETCD_NAME/$ETCD_NAME/g etcd.service
[fedora@ip-10-0-0-245 ~]$ sudo mv etcd.service /etc/systemd/system/
```


Start etcd on this node:
```
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```

Verify:
```
[fedora@ip-10-0-0-245 ~]$ sudo systemctl status etcd --no-pager
● etcd.service - etcd
   Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since Tue 2016-07-19 11:57:07 UTC; 14s ago
     Docs: https://github.com/coreos
 Main PID: 1229 (etcd)
    Tasks: 7 (limit: 512)
   CGroup: /system.slice/etcd.service
           └─1229 /usr/bin/etcd --name etcd1 --cert-file=/etc/etcd/kubernetes.pem --key-file=/etc/etcd/kubernetes-key.pem --peer-cert-file=/e...

Jul 19 11:57:18 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f [logterm: 1, index: 2] sent vote request to d41...rm 10
Jul 19 11:57:19 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f is starting a new election at term 10
Jul 19 11:57:19 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f became candidate at term 11
Jul 19 11:57:19 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f received vote from 8c16337be4f88b1f at term 11
Jul 19 11:57:19 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f [logterm: 1, index: 2] sent vote request to d41...rm 11
Jul 19 11:57:20 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f is starting a new election at term 11
Jul 19 11:57:20 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f became candidate at term 12
Jul 19 11:57:20 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f received vote from 8c16337be4f88b1f at term 12
Jul 19 11:57:20 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: 8c16337be4f88b1f [logterm: 1, index: 2] sent vote request to d41...rm 12
Jul 19 11:57:21 ip-10-0-0-245.eu-central-1.compute.internal etcd[1229]: publish error: etcdserver: request timed out
Hint: Some lines were ellipsized, use -l to show in full.
[fedora@ip-10-0-0-245 ~]$ 
```

Though at this point the etcd cluster is unhealthy, as we have not configured other etcd node yet.

```
[fedora@ip-10-0-0-245 ~]$ sudo etcdctl --ca-file=/etc/etcd/ca.pem cluster-health
member 8c16337be4f88b1f is unreachable: no available published client urls
member d41d031490df6efc is unreachable: no available published client urls
cluster is unhealthy
[fedora@ip-10-0-0-245 ~]$
```

At this point, prepare the other etcd node by repeating the above steps.

Once the other etcd nodes are also configured, the etcd cluster status should appear healthy:

```
[fedora@ip-10-0-0-246 ~]$ sudo etcdctl --ca-file=/etc/etcd/ca.pem cluster-health
member 8c16337be4f88b1f is healthy: got healthy result from https://10.0.0.245:2379
member d41d031490df6efc is healthy: got healthy result from https://10.0.0.246:2379
cluster is healthy
[fedora@ip-10-0-0-246 ~]$ 
```

-------------- 


# Bootstrapping an H/A Kubernetes Control Plane
We will also create a frontend load balancer with a public IP address for remote access to the API servers and H/A.

The Kubernetes components that make up the control plane include the following components:

* Kubernetes API Server
* Kubernetes Scheduler
* Kubernetes Controller Manager

Each component is being run on the same machines for the following reasons:

* The Scheduler and Controller Manager are tightly coupled with the API Server
* Only one Scheduler and Controller Manager can be active at a given time, but it's ok to run multiple at the same time. Each component will elect a leader via the API Server.
* Running multiple copies of each component is required for H/A
* Running each component next to the API Server eases configuration.

The following commands are to be repeated on all three controller managers:
Connect each controller manager using `ssh` command.


```
[kamran@kworkhorse ~]$ ssh -i Downloads/Kamran-AWS.pem fedora@controller1
[fedora@ip-10-0-0-137 ~]$ 
```



Setup TLS certificates in correct locations:
```
sudo mkdir -p /var/lib/kubernetes
sudo mv ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
```

Now, we see if we have the necessary software already pre-installed in these nodes. We are interested in kube-apiserver, kube-controller-manager, kube-scheduler and kubectl. Since the kubernetes controller nodes are based on Fedora Cloud Base, they do not have kubernetes installed in them. (which is good!)

```
[fedora@ip-10-0-0-137 ~]$ rpm -qa | grep kube
[fedora@ip-10-0-0-137 ~]$
```

## Download and install Kubernetes control libraries:

**Note:** If you are using kubernetes 1.2, you need to remove those and install kubernetes 1.3.  Remove the existing Kubernetes packages from the controller node, as they are older version, and do not support newer flags which we are going to use in configurations. Also the new CIDR network may be a problem with older kubernetes versions, so we install new versions. Also make sure to remove their left over config files too. It is because our service files have all the configurations in them, and having a separate config file will result in confusion.


Download and install latest Kubernetes (1.3):

```
[fedora@ip-10-0-0-137 ~]$ curl -s -O https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-apiserver
[fedora@ip-10-0-0-137 ~]$ curl -s -O https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-controller-manager
[fedora@ip-10-0-0-137 ~]$ curl -s -O https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-scheduler
[fedora@ip-10-0-0-137 ~]$ curl -s -O https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl


[fedora@ip-10-0-0-137 ~]$ chmod +x kube*

[fedora@ip-10-0-0-137 ~]$ sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/
``` 

**Note:** It needs to be ensured that the kubernetes binaries do not fail because of some non-existant pacakge. I hope these binaries are statically compiled and have everything built into them, which they need! (todo)



## Kubernetes API Server

Setup Authentication and Authorization

### Authentication
Token based authentication will be used to limit access to Kubernetes API.

```
[fedora@ip-10-0-0-137 ~]$ curl -O  https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/token.csv

[fedora@ip-10-0-0-137 ~]$ cat token.csv 
chAng3m3,admin,admin
chAng3m3,scheduler,scheduler
chAng3m3,kubelet,kubelet
[fedora@ip-10-0-0-137 ~]$

[fedora@ip-10-0-0-137 ~]$ sudo mv token.csv /var/lib/kubernetes/
```

### Authorization

Attribute-Based Access Control (ABAC) will be used to authorize access to the Kubernetes API. In this lab ABAC will be setup using the Kuberentes policy file backend as documented in the Kubernetes authorization guide.

```
[fedora@ip-10-0-0-137 ~]$ curl -sO  https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/authorization-policy.jsonl

[fedora@ip-10-0-0-137 ~]$ cat authorization-policy.jsonl 
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"*", "nonResourcePath": "*", "readonly": true}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"admin", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"scheduler", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"kubelet", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"group":"system:serviceaccounts", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
[fedora@ip-10-0-0-137 ~]$ 

[fedora@ip-10-0-0-137 ~]$ sudo mv authorization-policy.jsonl /var/lib/kubernetes/
```


## Create the systemd unit file

```
[fedora@ip-10-0-0-137 ~]$ INTERNAL_IP=10.0.0.137

[fedora@ip-10-0-0-137 ~]$ echo $INTERNAL_IP 
10.0.0.137
[fedora@ip-10-0-0-137 ~]$
```

```
cat > kube-apiserver.service <<"EOF"
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
  --etcd-servers=https://10.0.0.245:2379,https://10.0.0.246:2379 \
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
EOF
```


```
[fedora@ip-10-0-0-137 ~]$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-apiserver.service
[fedora@ip-10-0-0-137 ~]$ sudo mv kube-apiserver.service /etc/systemd/system/
[fedora@ip-10-0-0-137 ~]$ sudo systemctl daemon-reload
[fedora@ip-10-0-0-137 ~]$ sudo systemctl enable kube-apiserver
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-apiserver.service to /etc/systemd/system/kube-apiserver.service.
[fedora@ip-10-0-0-137 ~]$ 

[fedora@ip-10-0-0-137 ~]$ sudo systemctl start kube-apiserver

[fedora@ip-10-0-0-137 ~]$ sudo systemctl status kube-apiserver --no-pager
● kube-apiserver.service - Kubernetes API Server
   Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-07-21 09:15:48 UTC; 5s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 2530 (kube-apiserver)
    Tasks: 6 (limit: 512)
   CGroup: /system.slice/kube-apiserver.service
           └─2530 /usr/bin/kube-apiserver --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota...

Jul 21 09:15:48 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: W0721 09:15:48.774086    2530 controller.go:307] Resett...n:""
Jul 21 09:15:48 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: [restful] 2016/07/21 09:15:48 log.go:30: [restful/swagg...api/
Jul 21 09:15:48 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: [restful] 2016/07/21 09:15:48 log.go:30: [restful/swagg...-ui/
Jul 21 09:15:48 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: I0721 09:15:48.796906    2530 genericapiserver.go:690] ...6443
Jul 21 09:15:48 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: I0721 09:15:48.797022    2530 genericapiserver.go:734] ...8080
Jul 21 09:15:49 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: I0721 09:15:49.576728    2530 handlers.go:165] GET /api…47738]
Jul 21 09:15:49 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: I0721 09:15:49.577621    2530 handlers.go:165] GET /api…47730]
Jul 21 09:15:49 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: I0721 09:15:49.578230    2530 handlers.go:165] GET /api…47732]
Jul 21 09:15:49 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: I0721 09:15:49.578804    2530 handlers.go:165] GET /api…47734]
Jul 21 09:15:49 ip-10-0-0-137.eu-central-1.compute.internal kube-apiserver[2530]: I0721 09:15:49.579343    2530 handlers.go:165] GET /api…47736]
Hint: Some lines were ellipsized, use -l to show in full.
[fedora@ip-10-0-0-137 ~]$ 
```

API service started without a failure! Great!



## Kubernetes Controller Manager
```
cat > kube-controller-manager.service <<"EOF"
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
EOF
``` 

```
[fedora@ip-10-0-0-137 ~]$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-controller-manager.service
[fedora@ip-10-0-0-137 ~]$ sudo mv kube-controller-manager.service /etc/systemd/system/
[fedora@ip-10-0-0-137 ~]$ sudo systemctl daemon-reload
[fedora@ip-10-0-0-137 ~]$ sudo systemctl enable kube-controller-manager
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service to /etc/systemd/system/kube-controller-manager.service.
[fedora@ip-10-0-0-137 ~]$ sudo systemctl start kube-controller-manager

[fedora@ip-10-0-0-137 ~]$ sudo systemctl status kube-controller-manager --no-pager
● kube-controller-manager.service - Kubernetes Controller Manager
   Loaded: loaded (/etc/systemd/system/kube-controller-manager.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-07-21 09:42:05 UTC; 7s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 2596 (kube-controller)
    Tasks: 5 (limit: 512)
   CGroup: /system.slice/kube-controller-manager.service
           └─2596 /usr/bin/kube-controller-manager --allocate-node-cidrs=true --cluster-cidr=10.200.0.0/16 --cluster-name=kubernetes --leader...

Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: I0721 09:42:05.499016    2596 pet_set.go:144] S...ler
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: I0721 09:42:05.518558    2596 plugins.go:333] L...bs"
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: I0721 09:42:05.518721    2596 plugins.go:333] L...pd"
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: I0721 09:42:05.518833    2596 plugins.go:333] L...er"
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: E0721 09:42:05.519863    2596 util.go:45] Metri...red
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: I0721 09:42:05.520893    2596 attach_detach_con...ler
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: W0721 09:42:05.522418    2596 request.go:347] F...ly.
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: W0721 09:42:05.529666    2596 request.go:347] F...ly.
Jul 21 09:42:05 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: I0721 09:42:05.584072    2596 endpoints_control...tes
Jul 21 09:42:10 ip-10-0-0-137.eu-central-1.compute.internal kube-controller-manager[2596]: I0721 09:42:10.484616    2596 nodecontroller.go...de.
Hint: Some lines were ellipsized, use -l to show in full.
[fedora@ip-10-0-0-137 ~]$ 
```

This service runs without failing! Great!



## Kubernetes Scheduler

```
cat > kube-scheduler.service <<"EOF"
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
EOF
```


```
[fedora@ip-10-0-0-137 ~]$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-scheduler.service
[fedora@ip-10-0-0-137 ~]$ sudo mv kube-scheduler.service /etc/systemd/system/
[fedora@ip-10-0-0-137 ~]$ sudo systemctl daemon-reload
[fedora@ip-10-0-0-137 ~]$ sudo systemctl enable kube-scheduler
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-scheduler.service to /etc/systemd/system/kube-scheduler.service.
[fedora@ip-10-0-0-137 ~]$ sudo systemctl start kube-scheduler


[fedora@ip-10-0-0-137 ~]$ sudo systemctl status kube-scheduler --no-pager
● kube-scheduler.service - Kubernetes Scheduler
   Loaded: loaded (/etc/systemd/system/kube-scheduler.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-07-21 10:39:41 UTC; 6s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 2717 (kube-scheduler)
    Tasks: 5 (limit: 512)
   CGroup: /system.slice/kube-scheduler.service
           └─2717 /usr/bin/kube-scheduler --leader-elect=true --master=http://10.0.0.137:8080 --v=2

Jul 21 10:39:41 ip-10-0-0-137.eu-central-1.compute.internal systemd[1]: Started Kubernetes Scheduler.
Jul 21 10:39:41 ip-10-0-0-137.eu-central-1.compute.internal kube-scheduler[2717]: I0721 10:39:41.858568    2717 factory.go:255] Creating ...der'
Jul 21 10:39:41 ip-10-0-0-137.eu-central-1.compute.internal kube-scheduler[2717]: I0721 10:39:41.858781    2717 factory.go:301] creating sche...
Jul 21 10:39:41 ip-10-0-0-137.eu-central-1.compute.internal kube-scheduler[2717]: E0721 10:39:41.878924    2717 event.go:257] Could not const...
Jul 21 10:39:41 ip-10-0-0-137.eu-central-1.compute.internal kube-scheduler[2717]: I0721 10:39:41.879113    2717 leaderelection.go:215] su...uler
Hint: Some lines were ellipsized, use -l to show in full.
[fedora@ip-10-0-0-137 ~]$ 
```

Though we have configured only one master/controller for now, we can check the status:

```
[fedora@ip-10-0-0-137 ~]$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-1               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
[fedora@ip-10-0-0-137 ~]$ 
```

Repeat all these steps on remaining controller nodes. :)

```
[fedora@ip-10-0-0-138 ~]$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-1               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
[fedora@ip-10-0-0-138 ~]$
```

Notice that no matter how many controllers you have (three in our case), the word controller-manager appears only once in the output of the above command. That is probably because kubectl queries localhost and not all the controller nodes. 



## Future work:
To make it Highly Available, from outside, we would need to setup some sort of load balancer. Also to make it HA from the inside, we need to setup a (haproxy based) loadbalancer, which will be setup as a separate VM. (todo / interesting). May be these two load balancers can be combined into one with two interfaces?! (todo)

Note that at this point, Kelsey sets up an outside/frontend load balancer for these controllers. [https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-kubernetes-controller.md](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/04-kubernetes-controller.md) 


# Bootstrapping Kubernetes Workers

Reference: [https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-worker.md](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/05-kubernetes-worker.md)

**Note:** The OS on these nodes is changed to Fedora cloud base, because Fedora Atomic does not allow to add anything to the file system.
* Fedora-Cloud-Base-24-20160823.0.x86_64-eu-central-1-HVM-standard-0 - ami-2958a946


SSH into each worker node, and run the following commands.

## Move the TLS certificates in place

```
sudo mkdir -p /var/lib/kubernetes

sudo mv ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
``` 

## Docker

Kubernetes should be compatible with the Docker 1.9.x - 1.11.x:

```
curl -O https://get.docker.com/builds/Linux/x86_64/docker-1.11.2.tgz
tar xf docker-1.11.2.tgz
sudo cp docker/docker* /usr/bin/
```


Create docker service file:

```
sudo sh -c 'echo "[Unit]
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
WantedBy=multi-user.target" > /etc/systemd/system/docker.service'
```

**Note:** Do not use multi.user.wants in the service file's path above.

```
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker
```


```
[fedora@ip-10-0-0-182 ~]$ sudo docker version
Client:
 Version:      1.11.2
 API version:  1.23
 Go version:   go1.5.4
 Git commit:   b9f10c9
 Built:        Wed Jun  1 21:20:08 2016
 OS/Arch:      linux/amd64

Server:
 Version:      1.11.2
 API version:  1.23
 Go version:   go1.5.4
 Git commit:   b9f10c9
 Built:        Wed Jun  1 21:20:08 2016
 OS/Arch:      linux/amd64
[fedora@ip-10-0-0-182 ~]$ 
```


## Kubectl, kube-proxy and kubelet

The Kubernetes kubelet no longer relies on docker networking for pods! The Kubelet can now use CNI - the Container Network Interface to manage machine level networking requirements.

```
sudo mkdir -p /opt/cni
curl -O https://storage.googleapis.com/kubernetes-release/network-plugins/cni-c864f0e1ea73719b8f4582402b0847064f9883b0.tar.gz
sudo tar xf cni-c864f0e1ea73719b8f4582402b0847064f9883b0.tar.gz -C /opt/cni
```


```
[fedora@ip-10-0-0-181 ~]$ ls /opt/cni/bin/
bridge  cnitool  dhcp  flannel  host-local  ipvlan  loopback  macvlan  ptp  tuning
[fedora@ip-10-0-0-181 ~]$ 
```

I am not really sure, that how does kubernetes know about the existence of these binaries in /opt/cni/bin ? How does it setup CIDR network? [TODO]


## Download and install the Kubernetes worker binaries:

```
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-proxy
curl -O https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubelet

chmod +x kubectl kube-proxy kubelet
sudo mv kubectl kube-proxy kubelet /usr/bin/
``` 

```
sudo mkdir -p /var/lib/kubelet/
```


Mke sure to put in the internal IP address of the controller1 below for 'server'.
```
sudo sh -c 'echo "apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://10.0.0.137:6443
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
    token: chAng3m3" > /var/lib/kubelet/kubeconfig'
```
**Note:** We have used only one controller's address in this config file. Ideally, we should have a load balancer for this.


## Create the kubelet systemd unit file:
 
```
sudo sh -c 'echo "[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \
  --allow-privileged=true \
  --api-servers=https://10.0.0.137:6443,https://10.0.0.138:6443 \
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
WantedBy=multi-user.target" > /etc/systemd/system/kubelet.service'
``` 


```
sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl start kubelet
```

```
[fedora@ip-10-0-0-181 ~]$ sudo systemctl status kubelet --no-pager
● kubelet.service - Kubernetes Kubelet
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-08-25 13:05:31 UTC; 48s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 975 (kubelet)
    Tasks: 10 (limit: 512)
   CGroup: /system.slice/kubelet.service
           ├─ 975 /usr/bin/kubelet --allow-privileged=true --api-servers=https://10.0.0.137:6443,https://10.0.0.138:6443 --cloud-provider= --...
           └─1001 journalctl -k -f

Aug 25 13:05:32 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]:   }
Aug 25 13:05:32 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: }
Aug 25 13:05:36 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:05:36.858809     975 kubelet.go:2477] skipping pod syn...IDR]
Aug 25 13:05:41 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:05:41.859454     975 kubelet.go:2477] skipping pod syn...IDR]
Aug 25 13:05:46 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:05:46.859945     975 kubelet.go:2477] skipping pod syn...IDR]
Aug 25 13:05:51 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:05:51.860474     975 kubelet.go:2477] skipping pod syn...IDR]
Aug 25 13:05:56 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:05:56.860980     975 kubelet.go:2477] skipping pod syn...IDR]
Aug 25 13:06:01 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:06:01.861473     975 kubelet.go:2477] skipping pod syn...IDR]
Aug 25 13:06:02 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:06:02.117166     975 kubelet.go:2884] Recording NodeRe...rnal
Aug 25 13:06:06 ip-10-0-0-181.eu-central-1.compute.internal kubelet[975]: I0825 13:06:06.862013     975 kubelet.go:2534] SyncLoop (ADD, "...: ""
Hint: Some lines were ellipsized, use -l to show in full.
[fedora@ip-10-0-0-181 ~]$ 
```

## kube-proxy

```
sudo sh -c 'echo "[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy \
  --master=https://10.0.0.137:6443 \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --proxy-mode=iptables \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kube-proxy.service'
```


```
sudo systemctl daemon-reload
sudo systemctl enable kube-proxy
sudo systemctl start kube-proxy
```


```
[fedora@ip-10-0-0-181 ~]$ sudo systemctl status kube-proxy --no-pager
● kube-proxy.service - Kubernetes Kube Proxy
   Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-08-25 13:08:00 UTC; 11s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 1044 (kube-proxy)
    Tasks: 6 (limit: 512)
   CGroup: /system.slice/kube-proxy.service
           └─1044 /usr/bin/kube-proxy --master=https://10.0.0.137:6443 --kubeconfig=/var/lib/kubelet/kubeconfig --proxy-mode=iptables --v=2

Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal systemd[1]: Started Kubernetes Kube Proxy.
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.178074    1044 server.go:154] setting OOM sc...uild
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.183421    1044 server.go:201] Using iptables...ier.
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.183661    1044 server.go:214] Tearing down u...les.
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.191713    1044 conntrack.go:36] Setting nf_c...2144
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.191876    1044 conntrack.go:41] Setting conn...5536
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.192196    1044 conntrack.go:46] Setting nf_c...6400
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.223367    1044 proxier.go:502] Setting endpo...443]
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.223644    1044 proxier.go:647] Not syncing i...ster
Aug 25 13:08:00 ip-10-0-0-181.eu-central-1.compute.internal kube-proxy[1044]: I0825 13:08:00.224247    1044 proxier.go:427] Adding new se.../TCP
Hint: Some lines were ellipsized, use -l to show in full.
[fedora@ip-10-0-0-181 ~]$ 
```

## Verify that the nodes are in Ready state:
Logon to controller1 (or 2), and check the status of nodes:

```
[fedora@ip-10-0-0-137 ~]$ kubectl get nodes
NAME                                          STATUS    AGE
ip-10-0-0-181.eu-central-1.compute.internal   Ready     21h
ip-10-0-0-182.eu-central-1.compute.internal   Ready     21h
[fedora@ip-10-0-0-137 ~]$ 
```



**Note:** Make sure that you perform all of above steps on all worker nodes.

```
[fedora@ip-10-0-0-181 ~]$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 9001 qdisc fq_codel state UP group default qlen 1000
    link/ether 06:c8:b5:6e:b3:71 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.181/24 brd 10.0.0.255 scope global dynamic eth0
       valid_lft 2580sec preferred_lft 2580sec
    inet6 fe80::4c8:b5ff:fe6e:b371/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:c6:36:5e:e5 brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
[fedora@ip-10-0-0-181 ~]$ 
```

# Configuring the Kubernetes Client - Remote Access

Execute the following on your local work computer.

Linux

```
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```

# Configure the kubectl client to point to the Kubernetes API Server Frontend Load Balancer.

**Note:** This is a TODO task. Details below.

The instructions from Kelsey's document asks to point kubectl to the frontend load balancer. However, I did not configure that yet. So I will point kubectl to the pubic IP of the first controller only. 

**Note:** This IP address must be part of the cert you generated earlier.

But the problem is that in the beginning, we created certificates only with the public IP we generated earlier, which was to be assigned to the frontend load balancer. So even if I use the public IP of only one controller node, I would still not be able to use the kubectl from my work computer. This is a dilemma.

I tried to create an AWS load balancer, but i could not create it. It complained about the SSL certificates which I was providing it (which I generated in the begining of this document), and it refused. So I am really stuck here. [TODO]

This load balancer needs to be configured later. This is a TODO task.


For now, I can just log in directly on one of the controller nodes and do all the kubectl commands from there. So this is not a show stopper for now.

Another thing which could be done is to port forward port 6443 from the kubernetes controller to my work machine, over SSH. That way I can configure my kubectl to use localhost instead of that public IP. It would still point to only one controller, (as there is no frontend load balancer yet), but I can live with that. 


# Managing the Container Network Routes

Now that each worker node is online we need to add routes to make sure that Pods running on different machines can talk to each other. In this setup we are not going to provision any overlay networks (flannel), and instead rely on Layer 3 networking (cni). That means we need to add routes to our AWS router. In AWS each network has a router that can be configured. If this was an on-premesis datacenter then ideally you would need to add the routes to your local router.

In our setup we need to add the following routes to the AWS VPC router:

* Network 10.200.1.0/24 is reachable through 10.0.0.181
* Network 10.200.1.0/24 is reachable through 10.0.0.182

These are the networks, which will be created for pods' usage.10.0.0.181


We will use the following resources to configure our AWS VPC's router.

* [http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Route_Tables.html](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Route_Tables.html)
* [http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Route_Tables.html#AddRemoveRoutes](http://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/VPC_Route_Tables.html#AddRemoveRoutes)


The trick is to modify the main routing table and then add two routes. Instead of using the target IP address of the worker nodes, you have to use their EC2 instance IDs. 

(Attache screenshot)

# Create DNS addon
[https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-dns-addon.md](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-dns-addon.md)

Since kubectl on my local work computer is not setup yet. I will log on to the controller1, and execute the kubectl commands over there.

## Create the skydns service:
```
[kamran@kworkhorse ~]$ ssh -i Downloads/Kamran-AWS.pem fedora@controller1

[fedora@ip-10-0-0-137 ~]$ kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/skydns-svc.yaml
service "kube-dns" created
[fedora@ip-10-0-0-137 ~]$ 
```

```
[fedora@ip-10-0-0-137 ~]$ kubectl --namespace=kube-system get svc
NAME       CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   10.32.0.10   <none>        53/UDP,53/TCP   1m
[fedora@ip-10-0-0-137 ~]$
```


## Create the skydns replication controller:

```
kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/skydns-rc.yaml

[fedora@ip-10-0-0-137 ~]$ kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/skydns-rc.yaml
replicationcontroller "kube-dns-v18" created
[fedora@ip-10-0-0-137 ~]$ 
```


```
[fedora@ip-10-0-0-137 ~]$ kubectl --namespace=kube-system get pods
NAME                 READY     STATUS    RESTARTS   AGE
kube-dns-v18-04c4e   2/3       Running   0          41s
kube-dns-v18-t4xdi   2/3       Running   0          41s
[fedora@ip-10-0-0-137 ~]$ 
```


I wonder why it says 2/3 ? Why one of the containers is failing?

Also for some reason, the worker nodes started having the CIDR networks starting from 10.200.0.0/24, instead of 10.200.1.0/24 . Need to figure out how the node decides which network it is going to use. (TODO)

For now I have to change routes on AWS VPC.

So, changing routes on AWS VPC did not help much. The DNS containers remain in failed state, and one of them never comes up:

```
[fedora@ip-10-0-0-137 ~]$ kubectl get pods  --namespace=kube-system
NAME                 READY     STATUS             RESTARTS   AGE
kube-dns-v18-1rwo1   2/3       CrashLoopBackOff   31         1h
kube-dns-v18-qadgb   2/3       CrashLoopBackOff   31         1h
[fedora@ip-10-0-0-137 ~]$
```

```
[fedora@ip-10-0-0-137 ~]$ kubectl --namespace=kube-system  get events --watch-only=true
LASTSEEN               FIRSTSEEN              COUNT     NAME                 KIND      SUBOBJECT   TYPE      REASON       SOURCE                                                  MESSAGE
2016-08-26T12:33:53Z   2016-08-26T12:10:00Z   82        kube-dns-v18-04c4e   Pod                   Warning   FailedSync   {kubelet ip-10-0-0-182.eu-central-1.compute.internal}   Error syncing pod, skipping: failed to "StartContainer" for "kubedns" with CrashLoopBackOff: "Back-off 5m0s restarting failed container=kubedns pod=kube-dns-v18-04c4e_kube-system(0e9849e7-6b84-11e6-ad8b-06763c08460d)"

2016-08-26T12:33:53Z   2016-08-26T12:03:40Z   102       kube-dns-v18-04c4e   Pod       spec.containers{kubedns}   Warning   BackOff   {kubelet ip-10-0-0-182.eu-central-1.compute.internal}   Back-off restarting failed docker container
2016-08-26T12:33:57Z   2016-08-26T12:10:01Z   83        kube-dns-v18-t4xdi   Pod                 Warning   FailedSync   {kubelet ip-10-0-0-181.eu-central-1.compute.internal}   Error syncing pod, skipping: failed to "StartContainer" for "kubedns" with CrashLoopBackOff: "Back-off 5m0s restarting failed container=kubedns pod=kube-dns-v18-t4xdi_kube-system(0e989b19-6b84-11e6-ad8b-06763c08460d)"
```

```
[fedora@ip-10-0-0-137 ~]$ kubectl get rc --namespace=kube-system
NAME           DESIRED   CURRENT   AGE
kube-dns-v18   2         2         4d
[fedora@ip-10-0-0-137 ~]$

[fedora@ip-10-0-0-137 ~]$ kubectl get pods --namespace=kube-system
NAME                 READY     STATUS             RESTARTS   AGE
kube-dns-v18-1rwo1   2/3       CrashLoopBackOff   1602       4d
kube-dns-v18-qadgb   2/3       CrashLoopBackOff   1601       4d


[fedora@ip-10-0-0-137 ~]$ kubectl logs kube-dns-v18-qadgb -c kubedns --namespace=kube-system
Error from server: Get https://ip-10-0-0-182.eu-central-1.compute.internal:10250/containerLogs/kube-system/kube-dns-v18-qadgb/kubedns: x509: certificate is valid for etcd1, etcd2, controller1, controller2, worker1, worker2, not ip-10-0-0-182.eu-central-1.compute.internal
[fedora@ip-10-0-0-137 ~]$
```

The probem seems to be with the hostname of the nodes. The hostnames of the worker nodes are not simply worker1, and are not in the certificates we generated.


Flannel is a simpler solution compare to CIDR. But, Flannel is SDN, and has at least 30% degraded performance compared to CIDR. Even though I am tempted to use flannel here, I will try to make this Kubernetes work with CIDR. It is only this VPC router, which is kind of a challenge to configure.








