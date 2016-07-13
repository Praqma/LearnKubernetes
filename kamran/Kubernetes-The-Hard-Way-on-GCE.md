**Kubernetes the hard way - on GCE**
Reference: [https://github.com/kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way) 

# Install GCloud on your local work computer.

```
Steps: Todo
```

# Create a custom network
```
[kamran@kworkhorse ~]$ gcloud config list
Your active configuration is: [default]

[compute]
region = europe-west1
zone = europe-west1-b
[core]
account = kamranazeem@gmail.com
disable_usage_reporting = False
project = learn-kubernetes-1289


[kamran@kworkhorse ~]$ gcloud compute instances list
Listed 0 items.

[kamran@kworkhorse ~]$ gcloud compute networks create kubernetes --mode custom
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/global/networks/kubernetes].
NAME        MODE    IPV4_RANGE  GATEWAY_IPV4
kubernetes  custom

Instances on this network will not be reachable until firewall rules
are created. As an example, you can allow all internal traffic between
instances as well as SSH, RDP, and ICMP by running:

$ gcloud compute firewall-rules create <FIREWALL_NAME> --network kubernetes --allow tcp,udp,icmp --source-ranges <IP_RANGE>
$ gcloud compute firewall-rules create <FIREWALL_NAME> --network kubernetes --allow tcp:22,tcp:3389,icmp

[kamran@kworkhorse ~]$ 
```


# Create necessary firewall rules in GCE
```
gcloud compute firewall-rules create kubernetes-allow-icmp \
  --allow icmp \
  --network kubernetes \
  --source-ranges 0.0.0.0/0 

gcloud compute firewall-rules create kubernetes-allow-internal \
  --allow tcp:0-65535,udp:0-65535,icmp \
  --network kubernetes \
  --source-ranges 10.240.0.0/24

gcloud compute firewall-rules create kubernetes-allow-rdp \
  --allow tcp:3389 \
  --network kubernetes \
  --source-ranges 0.0.0.0/0

gcloud compute firewall-rules create kubernetes-allow-ssh \
  --allow tcp:22 \
  --network kubernetes \
  --source-ranges 0.0.0.0/0



gcloud compute firewall-rules create kubernetes-allow-healthz \
  --allow tcp:8080 \
  --network kubernetes \
  --source-ranges 130.211.0.0/22
```

**Note:** Why 130.211.0.0/22 ? It is the range of IPs out of which one will be assigned to our Kubernetes control plane, further below.

```
gcloud compute firewall-rules list --filter "network=kubernetes"

[kamran@kworkhorse ~]$ gcloud compute firewall-rules list --filter "network=kubernetes"
NAME                         NETWORK     SRC_RANGES      RULES                         SRC_TAGS  TARGET_TAGS
kubernetes-allow-api-server  kubernetes  0.0.0.0/0       tcp:6443
kubernetes-allow-healthz     kubernetes  130.211.0.0/22  tcp:8080
kubernetes-allow-icmp        kubernetes  0.0.0.0/0       icmp
kubernetes-allow-internal    kubernetes  10.240.0.0/24   tcp:0-65535,udp:0-65535,icmp
kubernetes-allow-rdp         kubernetes  0.0.0.0/0       tcp:3389
kubernetes-allow-ssh         kubernetes  0.0.0.0/0       tcp:22
[kamran@kworkhorse ~]$ 

```

# Create a public IP address that will be used by remote clients to connect to the Kubernetes control plane
```
[kamran@kworkhorse ~]$ gcloud compute addresses create kubernetes
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/regions/europe-west1/addresses/kubernetes].
---
address: 130.211.80.214
creationTimestamp: '2016-07-13T03:39:50.142-07:00'
description: ''
id: '3259022938852795545'
kind: compute#address
name: kubernetes
region: europe-west1
selfLink: https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/regions/europe-west1/addresses/kubernetes
status: RESERVED
[kamran@kworkhorse ~]$
```

```
[kamran@kworkhorse ~]$ gcloud compute addresses list kubernetes
NAME        REGION        ADDRESS         STATUS
kubernetes  europe-west1  130.211.80.214  RESERVED
[kamran@kworkhorse ~]$
```



# Setup etcd cluster:

etcd nodes are etcd1, etcd2, etcd3 

```
gcloud compute instances create etcd1 \
 --boot-disk-size 40GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.11 \
 --subnet kubernetes


[kamran@kworkhorse ~]$ gcloud compute instances create etcd1 \
>  --boot-disk-size 40GB \
>  --can-ip-forward \
>  --image ubuntu-1604-xenial-v20160627 \
>  --image-project ubuntu-os-cloud \
>  --machine-type n1-standard-1 \
>  --private-network-ip 10.240.0.11 \
>  --subnet kubernetes
WARNING: You have selected a disk size of under [200GB]. This may result in poor I/O performance. For more information, see: https://developers.google.com/compute/docs/disks#pdperformance.
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/zones/europe-west1-b/instances/etcd1].
NAME   ZONE            MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP      STATUS
etcd1  europe-west1-b  n1-standard-1               10.240.0.11  104.155.117.224  RUNNING
[kamran@kworkhorse ~]$ 
```

```
gcloud compute instances create etcd2 \
 --boot-disk-size 40GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.12 \
 --subnet kubernetes
```

```
gcloud compute instances create etcd3 \
 --boot-disk-size 40GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.13 \
 --subnet kubernetes
```


# Kubernetes Controllers
```
gcloud compute instances create controller1 \
 --boot-disk-size 40GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.21 \
 --subnet kubernetes


[kamran@kworkhorse ~]$ gcloud compute instances create controller1 \
>  --boot-disk-size 40GB \
>  --can-ip-forward \
>  --image ubuntu-1604-xenial-v20160627 \
>  --image-project ubuntu-os-cloud \
>  --machine-type n1-standard-1 \
>  --private-network-ip 10.240.0.21 \
>  --subnet kubernetes
WARNING: You have selected a disk size of under [200GB]. This may result in poor I/O performance. For more information, see: https://developers.google.com/compute/docs/disks#pdperformance.
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/zones/europe-west1-b/instances/controller1].
NAME         ZONE            MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP      STATUS
controller1  europe-west1-b  n1-standard-1               10.240.0.21  104.155.115.224  RUNNING
[kamran@kworkhorse ~]$ 
```

```
gcloud compute instances create controller2 \
 --boot-disk-size 40GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.22 \
 --subnet kubernetes
```

```
gcloud compute instances create controller3 \
 --boot-disk-size 40GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.23 \
 --subnet kubernetes
```

# Kubernetes Workers:

```
gcloud compute instances create worker1 \
 --boot-disk-size 200GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.31 \
 --subnet kubernetes


[kamran@kworkhorse ~]$ gcloud compute instances create worker1 \
>  --boot-disk-size 200GB \
>  --can-ip-forward \
>  --image ubuntu-1604-xenial-v20160627 \
>  --image-project ubuntu-os-cloud \
>  --machine-type n1-standard-1 \
>  --private-network-ip 10.240.0.31 \
>  --subnet kubernetes
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/zones/europe-west1-b/instances/worker1].
NAME     ZONE            MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
worker1  europe-west1-b  n1-standard-1               10.240.0.31  130.211.73.128  RUNNING
[kamran@kworkhorse ~]$ 
```


```
gcloud compute instances create worker2 \
 --boot-disk-size 200GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.32 \
 --subnet kubernetes
```

```
gcloud compute instances create worker3 \
 --boot-disk-size 200GB \
 --can-ip-forward \
 --image ubuntu-1604-xenial-v20160627 \
 --image-project ubuntu-os-cloud \
 --machine-type n1-standard-1 \
 --private-network-ip 10.240.0.33 \
 --subnet kubernetes
```


At the end of this step, you should have:
```
[kamran@kworkhorse ~]$ gcloud compute instances list
NAME         ZONE            MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP      STATUS
controller1  europe-west1-b  n1-standard-1               10.240.0.21  104.155.115.224  RUNNING
controller2  europe-west1-b  n1-standard-1               10.240.0.22  146.148.14.85    RUNNING
controller3  europe-west1-b  n1-standard-1               10.240.0.23  104.155.92.85    RUNNING
etcd1        europe-west1-b  n1-standard-1               10.240.0.11  104.155.117.224  RUNNING
etcd2        europe-west1-b  n1-standard-1               10.240.0.12  104.155.103.194  RUNNING
etcd3        europe-west1-b  n1-standard-1               10.240.0.13  130.211.105.167  RUNNING
worker1      europe-west1-b  n1-standard-1               10.240.0.31  130.211.73.128   RUNNING
worker2      europe-west1-b  n1-standard-1               10.240.0.32  104.155.96.192   RUNNING
worker3      europe-west1-b  n1-standard-1               10.240.0.33  104.155.38.99    RUNNING
[kamran@kworkhorse ~]$ 
```

```
[kamran@kworkhorse ~]$ gcloud compute addresses list
NAME        REGION        ADDRESS         STATUS
kubernetes  europe-west1  130.211.80.214  RESERVED
[kamran@kworkhorse ~]$ 
```

# Setup Certificate Authority and TLS certificate generation
We will use CFSSL (why? Todo)

## Install CFSSL

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
                    17:13
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
         9b:64:31:6d
[kamran@kworkhorse ~]$ 
```


## Generate the single Kubernetes TLS Cert

```
export KUBERNETES_PUBLIC_IP_ADDRESS=$(gcloud compute addresses describe kubernetes \
  --format 'value(address)')

echo $KUBERNETES_PUBLIC_IP_ADDRESS

[kamran@kworkhorse ~]$ export KUBERNETES_PUBLIC_IP_ADDRESS=$(gcloud compute addresses describe kubernetes \
>   --format 'value(address)')
[kamran@kworkhorse ~]$ echo $KUBERNETES_PUBLIC_IP_ADDRESS 
130.211.80.214
[kamran@kworkhorse ~]$ 
```


```
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "worker1",
    "worker2",
    "worker3",
    "10.32.0.1",
    "10.240.0.11",
    "10.240.0.12",
    "10.240.0.13",
    "10.240.0.21",
    "10.240.0.22",
    "10.240.0.23",
    "10.240.0.31",
    "10.240.0.32",
    "10.240.0.33",
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
[kamran@kworkhorse ~]$ cfssl gencert \
>   -ca=ca.pem \
>   -ca-key=ca-key.pem \
>   -config=ca-config.json \
>   -profile=kubernetes \
>   kubernetes-csr.json | cfssljson -bare kubernetes
2016/07/13 13:22:24 [INFO] generate received request
2016/07/13 13:22:24 [INFO] received CSR
2016/07/13 13:22:24 [INFO] generating key: rsa-2048
2016/07/13 13:22:24 [INFO] encoded CSR
2016/07/13 13:22:24 [INFO] signed certificate with serial number 717351128182836872996548155841113799582881627529
2016/07/13 13:22:24 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
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
-rw-rw-r--  1 kamran kamran  499 Jul 13 13:22 kubernetes-csr.json
-rw-rw-r--  1 kamran kamran 1.6K Jul 13 13:22 kubernetes.pem
-rw-------  1 kamran kamran 1.7K Jul 13 13:22 kubernetes-key.pem
-rw-r--r--  1 kamran kamran 1.2K Jul 13 13:22 kubernetes.csr
[kamran@kworkhorse ~]$ 
```
 

```
[kamran@kworkhorse ~]$ openssl x509 -in kubernetes.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            7d:a7:23:18:d6:59:31:10:da:23:1b:bf:cf:aa:14:b2:17:a3:3d:89
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Validity
            Not Before: Jul 13 11:17:00 2016 GMT
            Not After : Jul 13 11:17:00 2017 GMT
        Subject: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=Cluster, CN=kubernetes
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:b5:02:33:d6:8a:16:dd:cb:eb:48:37:38:ca:08:
                    2d:c0:b9:4a:7c:93:b0:ce:56:3a:2d:8d:6c:53:99:
                    47:a9:bb:e1:c7:30:cf:a8:22:e8:77:c5:24:fc:42:
                    fb:f5:8a:7a:8f:1b:b6:4f:a9:8a:e8:ae:45:bd:b1:
                    53:c4:0d:da:de:fa:f1:dd:42:14:c8:0a:53:7f:af:
                    56:6e:3c:6c:1a:8a:3f:aa:2d:48:c5:14:90:76:97:
                    a9:50:0f:fb:12:c3:e5:a1:37:c1:21:9b:07:59:e8:
                    18:e2:ba:a5:ea:93:76:23:d4:ce:0f:9d:22:3b:55:
                    29:5d:78:d0:c9:87:f3:e7:57:17:1e:41:ed:c6:f7:
                    75:64:91:54:97:15:1f:92:d8:22:ba:74:5b:cd:1a:
                    e3:b4:7a:e2:36:10:ac:06:16:5e:a9:19:2c:1f:82:
                    c2:b4:9b:0b:d5:3a:0e:49:51:9c:2d:ea:b1:db:20:
                    20:b1:6d:75:3a:cd:49:33:4b:5b:0d:d0:f1:b5:da:
                    69:a5:e3:40:3a:f1:f4:4a:13:de:71:ee:ca:9f:30:
                    d5:84:25:43:cf:0f:6b:4a:ff:e9:3c:f9:9d:0b:38:
                    e7:37:f4:5c:23:ad:48:14:3b:91:6d:04:6a:9c:28:
                    7b:1a:92:cc:f0:dd:92:78:de:20:0f:48:49:4d:96:
                    1e:f5
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier: 
                31:6F:17:18:4A:AB:24:93:6E:3A:1F:48:69:62:44:CD:1A:DC:61:35
            X509v3 Authority Key Identifier: 
                keyid:43:B4:D8:70:0A:43:2B:61:A7:22:ED:54:69:15:D2:04:46:93:3E:E5

            X509v3 Subject Alternative Name: 
                DNS:worker1, DNS:worker2, DNS:worker3, IP Address:10.32.0.1, IP Address:10.240.0.11, IP Address:10.240.0.12, IP Address:10.240.0.13, IP Address:10.240.0.21, IP Address:10.240.0.22, IP Address:10.240.0.23, IP Address:10.240.0.31, IP Address:10.240.0.32, IP Address:10.240.0.33, IP Address:130.211.80.214, IP Address:127.0.0.1
    Signature Algorithm: sha256WithRSAEncryption
         9f:9c:81:77:cc:db:ec:50:06:c7:72:6b:82:14:7c:b6:e6:f0:
         14:66:a0:e9:97:59:25:a8:03:0e:32:94:02:06:12:a6:b3:99:
         8b:8d:ee:ab:4e:ac:4d:15:fe:e9:1e:87:54:f3:f2:43:e4:73:
         d3:61:3a:e6:10:9f:89:04:76:84:ac:93:c7:07:6d:79:4c:c4:
         71:df:b3:1c:6f:af:01:b5:86:9d:8e:de:f0:14:31:29:3e:36:
         34:f8:5d:ff:8a:94:21:47:2f:31:84:1e:83:29:2a:49:25:37:
         be:18:f2:3a:4a:3d:69:c4:44:93:26:5b:06:fb:a0:db:a4:fe:
         e8:bf:84:fe:59:da:56:db:e4:8f:a1:da:f9:44:c4:a9:f2:d8:
         62:da:a7:d0:2d:65:c6:6f:83:ab:f4:fe:5a:7a:92:1c:af:0f:
         5d:48:1f:1a:63:9e:d5:6d:88:40:db:f5:54:52:3f:58:12:57:
         df:e9:3c:91:18:68:4e:d2:ed:90:2b:96:60:bd:fe:53:03:bb:
         61:d9:a8:14:01:d5:81:da:66:11:3a:a5:e2:57:be:22:4c:80:
         78:dd:e4:c5:4f:c0:16:0f:c7:38:6a:6f:88:54:d7:2d:83:8a:
         ac:3a:88:02:1c:f7:87:55:40:76:bd:5b:5c:5e:8c:f0:a8:14:
         9c:9e:81:b1
[kamran@kworkhorse ~]$ 
```

Copy TLS Certs to proper locations in respective nodes:

```
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem controller1:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem controller2:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem controller3:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem etcd1:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem etcd2:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem etcd3:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem worker1:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem worker2:~/
gcloud compute copy-files ca.pem kubernetes-key.pem kubernetes.pem worker3:~/
```


# Setup HA etcd cluster:

Run the following commands on etcd1, etcd2, etcd3:

SSH into each machine using the `gcloud compute ssh` command


```
[kamran@kworkhorse ~]$ gcloud compute ssh etcd1
Welcome to Ubuntu 16.04 LTS (GNU/Linux 4.4.0-28-generic x86_64)

 * Documentation:  https://help.ubuntu.com/

  Get cloud support with Ubuntu Advantage Cloud Guest:
    http://www.ubuntu.com/business/services/cloud

0 packages can be updated.
0 updates are security updates.


To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

kamran@etcd1:~$
```

Move the TLS certificates in place:
```
kamran@etcd1:~$ sudo mkdir -p /etc/etcd/
kamran@etcd1:~$ sudo mv ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/

```

Download and install the etcd binaries:
```
kamran@etcd1:~$ wget https://github.com/coreos/etcd/releases/download/v3.0.1/etcd-v3.0.1-linux-amd64.tar.gz
Resolving github-cloud.s3.amazonaws.com (github-cloud.s3.amazonaws.com)... 54.231.115.27
Connecting to github-cloud.s3.amazonaws.com (github-cloud.s3.amazonaws.com)|54.231.115.27|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 10300993 (9.8M) [application/octet-stream]
Saving to: ‘etcd-v3.0.1-linux-amd64.tar.gz’

etcd-v3.0.1-linux-amd64.tar.gz      100%[===================================================================>]   9.82M  2.90MB/s    in 3.5s    

2016-07-13 11:31:45 (2.78 MB/s) - ‘etcd-v3.0.1-linux-amd64.tar.gz’ saved [10300993/10300993]

kamran@etcd1:~$ tar -xf etcd-v3.0.1-linux-amd64.tar.gz
kamran@etcd1:~$ sudo cp etcd-v3.0.1-linux-amd64/etcd* /usr/bin/
kamran@etcd1:~$ sudo mkdir -p /var/lib/etcd
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
  --initial-cluster etcd1=https://10.240.0.11:2380,etcd2=https://10.240.0.12:2380,etcd3=https://10.240.0.13:2380 \
  --initial-cluster-state new \
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

```
kamran@etcd1:~$ export INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
>   http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
kamran@etcd1:~$ 

kamran@etcd1:~$ echo $INTERNAL_IP 
10.240.0.11
kamran@etcd1:~$ 
```


```
kamran@etcd1:~$ export ETCD_NAME=$(hostname -s)

kamran@etcd1:~$ echo $ETCD_NAME 
etcd1
kamran@etcd1:~$ 
```

Now, replace the names with values in the service file, and move the service file to proper location:
```
kamran@etcd1:~$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g etcd.service
kamran@etcd1:~$ sed -i s/ETCD_NAME/$ETCD_NAME/g etcd.service
kamran@etcd1:~$ sudo mv etcd.service /etc/systemd/system/
```

Start etcd on this node:
```
sudo systemctl daemon-reload
sudo systemctl enable etcd
sudo systemctl start etcd
```

Verify:
```
kamran@etcd1:~$ sudo systemctl status etcd --no-pager
● etcd.service - etcd
   Loaded: loaded (/etc/systemd/system/etcd.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2016-07-13 11:47:23 UTC; 10s ago
     Docs: https://github.com/coreos
 Main PID: 3543 (etcd)
    Tasks: 7
   Memory: 6.8M
      CPU: 205ms
   CGroup: /system.slice/etcd.service
           └─3543 /usr/bin/etcd --name etcd1 --cert-file=/etc/etcd/kubernetes.pem --key-file=/etc/etcd/kubernetes-key.pem --peer-cert-file=/e...

Jul 13 11:47:31 etcd1 etcd[3543]: ffed16798470cab5 is starting a new election at term 6
Jul 13 11:47:31 etcd1 etcd[3543]: ffed16798470cab5 became candidate at term 7
Jul 13 11:47:31 etcd1 etcd[3543]: ffed16798470cab5 received vote from ffed16798470cab5 at term 7
Jul 13 11:47:31 etcd1 etcd[3543]: ffed16798470cab5 [logterm: 1, index: 3] sent vote request to 2fe2f5d17fc97dab at term 7
Jul 13 11:47:31 etcd1 etcd[3543]: ffed16798470cab5 [logterm: 1, index: 3] sent vote request to 3a57933972cb5131 at term 7
Jul 13 11:47:33 etcd1 etcd[3543]: ffed16798470cab5 is starting a new election at term 7
Jul 13 11:47:33 etcd1 etcd[3543]: ffed16798470cab5 became candidate at term 8
Jul 13 11:47:33 etcd1 etcd[3543]: ffed16798470cab5 received vote from ffed16798470cab5 at term 8
Jul 13 11:47:33 etcd1 etcd[3543]: ffed16798470cab5 [logterm: 1, index: 3] sent vote request to 2fe2f5d17fc97dab at term 8
Jul 13 11:47:33 etcd1 etcd[3543]: ffed16798470cab5 [logterm: 1, index: 3] sent vote request to 3a57933972cb5131 at term 8
kamran@etcd1:~$ 
``` 

Though at this point the etcd cluster is unhealthy, as we have not configured other two nodes yet.

```
kamran@etcd1:~$ etcdctl --ca-file=/etc/etcd/ca.pem cluster-health
cluster may be unhealthy: failed to list members
Error:  client: etcd cluster is unavailable or misconfigured
error #0: dial tcp 127.0.0.1:4001: getsockopt: connection refused
error #1: client: endpoint http://127.0.0.1:2379 exceeded header timeout

kamran@etcd1:~$
```

At this point, prepare the other two etcd nodes by repeating the above steps.

Once the other etcd nodes are also configured, the etcd cluster status should appear healthy:

```
kamran@etcd3:~$ etcdctl --ca-file=/etc/etcd/ca.pem cluster-health
member 2fe2f5d17fc97dab is healthy: got healthy result from https://10.240.0.13:2379
member 3a57933972cb5131 is healthy: got healthy result from https://10.240.0.12:2379
member ffed16798470cab5 is healthy: got healthy result from https://10.240.0.11:2379
cluster is healthy
kamran@etcd3:~$ 
```




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
Connect each controller manager using `gcloud compute ssh <Node>`

```
[kamran@kworkhorse ~]$ gcloud compute ssh controller1
Welcome to Ubuntu 16.04 LTS (GNU/Linux 4.4.0-28-generic x86_64)

 * Documentation:  https://help.ubuntu.com/

  Get cloud support with Ubuntu Advantage Cloud Guest:
    http://www.ubuntu.com/business/services/cloud

0 packages can be updated.
0 updates are security updates.


Last login: Wed Jul 13 13:01:25 2016 from 90.149.102.56
To run a command as administrator (user "root"), use "sudo <command>".
See "man sudo_root" for details.

kamran@controller1:~$ 
```

Setup TLS certificates in correct locations:
```
sudo mkdir -p /var/lib/kubernetes
sudo mv ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
```


Download and install Kubernetes control libraries:
```
kamran@controller1:~$ wget -q https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-apiserver
kamran@controller1:~$ wget -q https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-controller-manager
kamran@controller1:~$ wget -q https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-scheduler
kamran@controller1:~$ wget -q https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl

kamran@controller1:~$ chmod +x kube*

kamran@controller1:~$ sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/bin/
``` 


## Kubernetes API Server

Setup Authentication and Authorization

### Authentication
Token based authentication will be used to limit access to Kubernetes API.

```
kamran@controller1:~$ wget https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/token.csv

kamran@controller1:~$ cat token.csv 
chAng3m3,admin,admin
chAng3m3,scheduler,scheduler
chAng3m3,kubelet,kubelet
kamran@controller1:~$ 

kamran@controller1:~$ sudo mv token.csv /var/lib/kubernetes/
```

### Authorization

Attribute-Based Access Control (ABAC) will be used to authorize access to the Kubernetes API. In this lab ABAC will be setup using the Kuberentes policy file backend as documented in the Kubernetes authorization guide.

```
kamran@controller1:~$ wget https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/authorization-policy.jsonl


kamran@controller1:~$ cat authorization-policy.jsonl
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"*", "nonResourcePath": "*", "readonly": true}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"admin", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"scheduler", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"kubelet", "namespace": "*", "resource": "*", "apiGroup": "*"}}
{"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"group":"system:serviceaccounts", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
kamran@controller1:~$ 


sudo mv authorization-policy.jsonl /var/lib/kubernetes/
```

## Create the systemd unit file
```
kamran@controller1:~$ export INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
>   http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

kamran@controller1:~$ echo $INTERNAL_IP 
10.240.0.21
kamran@controller1:~$ 
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
  --apiserver-count=3 \
  --authorization-mode=ABAC \
  --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl \
  --bind-address=0.0.0.0 \
  --enable-swagger-ui=true \
  --etcd-cafile=/var/lib/kubernetes/ca.pem \
  --insecure-bind-address=0.0.0.0 \
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \
  --etcd-servers=https://10.240.0.11:2379,https://10.240.0.12:2379,https://10.240.0.13:2379 \
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
kamran@controller1:~$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-apiserver.service

kamran@controller1:~$ sudo mv kube-apiserver.service /etc/systemd/system/
kamran@controller1:~$ sudo systemctl daemon-reload
kamran@controller1:~$ sudo systemctl enable kube-apiserver
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-apiserver.service to /etc/systemd/system/kube-apiserver.service.
kamran@controller1:~$ sudo systemctl start kube-apiserver

kamran@controller1:~$ sudo systemctl status kube-apiserver --no-pager
● kube-apiserver.service - Kubernetes API Server
   Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; vendor preset: enabled)
   Active: activating (auto-restart) (Result: exit-code) since Wed 2016-07-13 13:14:30 UTC; 3s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
  Process: 5209 ExecStart=/usr/bin/kube-apiserver --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota --advertise-address=10.240.0.21 --allow-privileged=true --apiserver-count=3 --authorization-mode=ABAC --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl --bind-address=0.0.0.0 --enable-swagger-ui=true --etcd-cafile=/var/lib/kubernetes/ca.pem --insecure-bind-address=0.0.0.0 --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem --etcd-servers=https://10.240.0.11:2379,https://10.240.0.12:2379,https://10.240.0.13:2379 --service-account-key-file=/var/lib/kubernetes/kubernetes-key.pem --service-cluster-ip-range=10.32.0.0/24 --service-node-port-range=30000-32767 --tls-cert-file=/var/lib/kubernetes/kubernetes.pem --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --token-auth-file=/var/lib/kubernetes/token.csv --v=2 (code=exited, status=255)
 Main PID: 5209 (code=exited, status=255)

Jul 13 13:14:30 controller1 systemd[1]: kube-apiserver.service: Main process exited, code=exited, status=255/n/a
Jul 13 13:14:30 controller1 systemd[1]: kube-apiserver.service: Unit entered failed state.
Jul 13 13:14:30 controller1 systemd[1]: kube-apiserver.service: Failed with result 'exit-code'.
kamran@controller1:~$ 
```

Failure? Why ? 

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
kamran@controller1:~$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-controller-manager.service
kamran@controller1:~$ sudo mv kube-controller-manager.service /etc/systemd/system/
kamran@controller1:~$ sudo systemctl daemon-reload
kamran@controller1:~$ sudo systemctl enable kube-controller-manager
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service to /etc/systemd/system/kube-controller-manager.service.
kamran@controller1:~$ sudo systemctl start kube-controller-manager
kamran@controller1:~$ 
```


```
kamran@controller1:~$ sudo systemctl status kube-controller-manager --no-pager
● kube-controller-manager.service - Kubernetes Controller Manager
   Loaded: loaded (/etc/systemd/system/kube-controller-manager.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2016-07-13 13:17:03 UTC; 30s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 5588 (kube-controller)
    Tasks: 5
   Memory: 6.4M
      CPU: 42ms
   CGroup: /system.slice/kube-controller-manager.service
           └─5588 /usr/bin/kube-controller-manager --allocate-node-cidrs=true --cluster-cidr=10.200.0.0/16 --cluster-name=kubernetes --leader...

Jul 13 13:17:03 controller1 kube-controller-manager[5588]: E0713 13:17:03.422315    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:06 controller1 kube-controller-manager[5588]: E0713 13:17:06.875065    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:11 controller1 kube-controller-manager[5588]: E0713 13:17:11.133805    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:14 controller1 kube-controller-manager[5588]: E0713 13:17:14.729596    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:17 controller1 kube-controller-manager[5588]: E0713 13:17:17.780732    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:20 controller1 kube-controller-manager[5588]: E0713 13:17:20.800514    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:24 controller1 kube-controller-manager[5588]: E0713 13:17:24.449491    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:26 controller1 kube-controller-manager[5588]: E0713 13:17:26.607742    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:28 controller1 kube-controller-manager[5588]: E0713 13:17:28.984164    5588 leaderelection.go:253] error retrieving endpoi...efused
Jul 13 13:17:31 controller1 kube-controller-manager[5588]: E0713 13:17:31.217712    5588 leaderelection.go:253] error retrieving endpoi...efused
Hint: Some lines were ellipsized, use -l to show in full.
kamran@controller1:~$ 
```

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
kamran@controller1:~$ sed -i s/INTERNAL_IP/$INTERNAL_IP/g kube-scheduler.service
kamran@controller1:~$ sudo mv kube-scheduler.service /etc/systemd/system/
kamran@controller1:~$ sudo systemctl daemon-reload
kamran@controller1:~$ sudo systemctl enable kube-scheduler
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-scheduler.service to /etc/systemd/system/kube-scheduler.service.
kamran@controller1:~$ sudo systemctl start kube-scheduler
```

```
kamran@controller1:~$ sudo systemctl status kube-scheduler --no-pager
● kube-scheduler.service - Kubernetes Scheduler
   Loaded: loaded (/etc/systemd/system/kube-scheduler.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2016-07-13 13:19:01 UTC; 27s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 5869 (kube-scheduler)
    Tasks: 5
   Memory: 6.4M
      CPU: 120ms
   CGroup: /system.slice/kube-scheduler.service
           └─5869 /usr/bin/kube-scheduler --leader-elect=true --master=http://10.240.0.21:8080 --v=2

Jul 13 13:19:28 controller1 kube-scheduler[5869]: E0713 13:19:28.006905    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Jul 13 13:19:28 controller1 kube-scheduler[5869]: E0713 13:19:28.007398    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.000589    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/scheduler/fact...
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.001459    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.001702    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.002125    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.002785    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.003054    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/scheduler/fact...
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.008114    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Jul 13 13:19:29 controller1 kube-scheduler[5869]: E0713 13:19:29.008480    5869 reflector.go:216] k8s.io/kubernetes/plugin/pkg/schedul...refused
Hint: Some lines were ellipsized, use -l to show in full.
kamran@controller1:~$ 
```


Check apiserver status once again:

```
kamran@controller1:~$ sudo systemctl status kube-apiserver --no-pager
● kube-apiserver.service - Kubernetes API Server
   Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; vendor preset: enabled)
   Active: activating (auto-restart) (Result: exit-code) since Wed 2016-07-13 13:20:06 UTC; 636ms ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
  Process: 6005 ExecStart=/usr/bin/kube-apiserver --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota --advertise-address=10.240.0.21 --allow-privileged=true --apiserver-count=3 --authorization-mode=ABAC --authorization-policy-file=/var/lib/kubernetes/authorization-policy.jsonl --bind-address=0.0.0.0 --enable-swagger-ui=true --etcd-cafile=/var/lib/kubernetes/ca.pem --insecure-bind-address=0.0.0.0 --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem --etcd-servers=https://10.240.0.11:2379,https://10.240.0.12:2379,https://10.240.0.13:2379 --service-account-key-file=/var/lib/kubernetes/kubernetes-key.pem --service-cluster-ip-range=10.32.0.0/24 --service-node-port-range=30000-32767 --tls-cert-file=/var/lib/kubernetes/kubernetes.pem --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem --token-auth-file=/var/lib/kubernetes/token.csv --v=2 (code=exited, status=255)
 Main PID: 6005 (code=exited, status=255)

Jul 13 13:20:06 controller1 systemd[1]: kube-apiserver.service: Main process exited, code=exited, status=255/n/a
Jul 13 13:20:06 controller1 systemd[1]: kube-apiserver.service: Unit entered failed state.
Jul 13 13:20:06 controller1 systemd[1]: kube-apiserver.service: Failed with result 'exit-code'.
kamran@controller1:~$ 
```

Still failing!!!!  (todo) 

```
kamran@controller1:~$ kubectl get componentstatuses
The connection to the server localhost:8080 was refused - did you specify the right host or port?
kamran@controller1:~$ 
```

What? !!!

```
journalctl -f shows:

Jul 13 13:24:31 controller1 kube-apiserver[6560]: F0713 13:24:31.180865    6560 server.go:238] Invalid Authorization Config: open /var/lib/kubernetes/authorization-policy.jsonl: no such file or directory
```

I forgot to place the authorization policy at the right place. After I did that, I restarted service, and got it working:

```
kamran@controller1:~$ sudo systemctl status kube-apiserver --no-pager
● kube-apiserver.service - Kubernetes API Server
   Loaded: loaded (/etc/systemd/system/kube-apiserver.service; enabled; vendor preset: enabled)
   Active: active (running) since Wed 2016-07-13 13:26:46 UTC; 1min 7s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 6785 (kube-apiserver)
    Tasks: 5
   Memory: 31.3M
      CPU: 617ms
   CGroup: /system.slice/kube-apiserver.service
           └─6785 /usr/bin/kube-apiserver --admission-control=NamespaceLifecycle,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota...

Jul 13 13:27:49 controller1 kube-apiserver[6785]: I0713 13:27:49.344766    6785 handlers.go:165] PUT /api/v1/namespaces/kube-system/en...:60588]
Jul 13 13:27:50 controller1 kube-apiserver[6785]: I0713 13:27:50.698547    6785 handlers.go:165] GET /api/v1/namespaces/kube-system/en...:60552]
Jul 13 13:27:50 controller1 kube-apiserver[6785]: I0713 13:27:50.704522    6785 handlers.go:165] PUT /api/v1/namespaces/kube-system/en...:60552]
Jul 13 13:27:51 controller1 kube-apiserver[6785]: I0713 13:27:51.347407    6785 handlers.go:165] GET /api/v1/namespaces/kube-system/en...:60588]
Jul 13 13:27:51 controller1 kube-apiserver[6785]: I0713 13:27:51.353738    6785 handlers.go:165] PUT /api/v1/namespaces/kube-system/en...:60588]
Jul 13 13:27:52 controller1 kube-apiserver[6785]: I0713 13:27:52.339100    6785 handlers.go:165] GET /api/v1/nodes: (1.363491ms) 200 [...:60552]
Jul 13 13:27:52 controller1 kube-apiserver[6785]: I0713 13:27:52.707466    6785 handlers.go:165] GET /api/v1/namespaces/kube-system/en...:60552]
Jul 13 13:27:52 controller1 kube-apiserver[6785]: I0713 13:27:52.714824    6785 handlers.go:165] PUT /api/v1/namespaces/kube-system/en...:60552]
Jul 13 13:27:53 controller1 kube-apiserver[6785]: I0713 13:27:53.356507    6785 handlers.go:165] GET /api/v1/namespaces/kube-system/en...:60588]
Jul 13 13:27:53 controller1 kube-apiserver[6785]: I0713 13:27:53.364174    6785 handlers.go:165] PUT /api/v1/namespaces/kube-system/en...:60588]
Hint: Some lines were ellipsized, use -l to show in full.
kamran@controller1:~$ 
```


Cluster status now:
```
kamran@controller1:~$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-1               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}   
kamran@controller1:~$ 
```

Repeat all these steps on remaining controller nodes. :)






