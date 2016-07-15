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

When you will be done setting up Kubernetes API related services on all three controllers, you should check the status again. 
```
kamran@controller3:~$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
kamran@controller3:~$ 
```

Notice that no matter how many controllers you have (three in our case), the word controller-manager appears only once in the output of the above command.

# Setup Kubernetes API Server Frontend Load Balancer
Execute the commands from the local work computer:

```
[kamran@kworkhorse ~]$ gcloud compute http-health-checks create kube-apiserver-check \
>   --description "Kubernetes API Server Health Check" \
>   --port 8080 \
>   --request-path /healthz
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/global/httpHealthChecks/kube-apiserver-check].
NAME                  HOST  PORT  REQUEST_PATH
kube-apiserver-check        8080  /healthz
[kamran@kworkhorse ~]$ 
```

```
[kamran@kworkhorse ~]$ gcloud compute target-pools create kubernetes-pool \
>   --health-check kube-apiserver-check \
>   --region europe-west1
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/regions/europe-west1/targetPools/kubernetes-pool].
NAME             REGION        SESSION_AFFINITY  BACKUP  HEALTH_CHECKS
kubernetes-pool  europe-west1                            kube-apiserver-check
[kamran@kworkhorse ~]$ 
``` 

```
gcloud compute target-pools add-instances kubernetes-pool \
  --instances controller1,controller2,controller3



[kamran@kworkhorse ~]$ gcloud compute target-pools add-instances kubernetes-pool \
>   --instances controller1,controller2,controller3

Updated [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/regions/europe-west1/targetPools/kubernetes-pool].
[kamran@kworkhorse ~]$ 
```


```
[kamran@kworkhorse ~]$ export KUBERNETES_PUBLIC_IP_ADDRESS=$(gcloud compute addresses describe kubernetes \
>   --format 'value(address)')

[kamran@kworkhorse ~]$ 


[kamran@kworkhorse ~]$ echo $KUBERNETES_PUBLIC_IP_ADDRESS 
130.211.80.214
[kamran@kworkhorse ~]$ 
```


```
gcloud compute forwarding-rules create kubernetes-rule \
  --address ${KUBERNETES_PUBLIC_IP_ADDRESS} \
  --ports 6443 \
  --target-pool kubernetes-pool

[kamran@kworkhorse ~]$ gcloud compute forwarding-rules create kubernetes-rule \
>   --address ${KUBERNETES_PUBLIC_IP_ADDRESS} \
>   --ports 6443 \
>   --target-pool kubernetes-pool
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/regions/europe-west1/forwardingRules/kubernetes-rule].
---
IPAddress: 130.211.80.214
IPProtocol: TCP
creationTimestamp: '2016-07-14T02:27:41.967-07:00'
description: ''
id: '4566357756225447394'
kind: compute#forwardingRule
name: kubernetes-rule
portRange: 6443-6443
region: europe-west1
selfLink: https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/regions/europe-west1/forwardingRules/kubernetes-rule
target: europe-west1/targetPools/kubernetes-pool
[kamran@kworkhorse ~]$ 
```

-----

# Setup Kubernetes Workers

Run the following commands on worker1, worker2, worker3.


```
sudo mkdir -p /var/lib/kubernetes

sudo mv ca.pem kubernetes-key.pem kubernetes.pem /var/lib/kubernetes/
```

```
kamran@worker1:~$ wget https://get.docker.com/builds/Linux/x86_64/docker-1.11.2.tgz

2016-07-14 09:36:44 (35.3 MB/s) - ‘docker-1.11.2.tgz’ saved [20537862/20537862]

kamran@worker1:~$ tar -xf docker-1.11.2.tgz
kamran@worker1:~$ sudo cp docker/docker* /usr/bin/
```

Create Docker systemd file:
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


```
sudo systemctl daemon-reload
sudo systemctl enable docker
sudo systemctl start docker
```

Setup kubelet on each worker:
The Kubernetes kubelet no longer relies on docker networking for pods! The Kubelet can now use CNI - the Container Network Interface to manage machine level networking requirements.

Download and install CNI plugins. 

```
kamran@worker3:~$ sudo mkdir -p /opt/cni

kamran@worker3:~$ wget https://storage.googleapis.com/kubernetes-release/network-plugins/cni-c864f0e1ea73719b8f4582402b0847064f9883b0.tar.gz

kamran@worker3:~$ sudo tar -xvf cni-c864f0e1ea73719b8f4582402b0847064f9883b0.tar.gz -C /opt/cni
bin/
bin/flannel
bin/ipvlan
bin/loopback
bin/ptp
bin/tuning
bin/bridge
bin/host-local
bin/macvlan
bin/cnitool
bin/dhcp
kamran@worker3:~$
```


```
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-proxy
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubelet
```


```
kamran@worker1:~$ chmod +x kubectl kube-proxy kubelet
kamran@worker1:~$ sudo mv kubectl kube-proxy kubelet /usr/bin/
kamran@worker1:~$ sudo mkdir -p /var/lib/kubelet/

```

```
sudo sh -c 'echo "apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority: /var/lib/kubernetes/ca.pem
    server: https://10.240.0.21:6443
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

**Note:** Maybe we should use the controller's load balancer/cluster IP instead of using controller1's IP ?
**Answer**: [https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/27](https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/27)


Create the kubelet systemd unit file:
```
sudo sh -c 'echo "[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/bin/kubelet \
  --allow-privileged=true \
  --api-servers=https://10.240.0.21:6443,https://10.240.0.22:6443,https://10.240.0.23:6443 \
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

Notice the presence of `--configure-cbr0=true` and `--network-plugin=kubenet` and `--reconcile-cidr=true` . These help a worker node setup a container/pod network. How they pick up a specific address scheme such as **10.200.1.0/24** is something I need to look into. (todo)



```
kamran@worker1:~$ sudo systemctl daemon-reload
kamran@worker1:~$ sudo systemctl enable kubelet
Created symlink from /etc/systemd/system/multi-user.target.wants/kubelet.service to /etc/systemd/system/kubelet.service.
kamran@worker1:~$ sudo systemctl start kubelet


kamran@worker1:~$ sudo systemctl status kubelet --no-pager
● kubelet.service - Kubernetes Kubelet
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2016-07-14 09:46:28 UTC; 5s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 6709 (kubelet)
    Tasks: 10
   Memory: 16.4M
      CPU: 243ms
   CGroup: /system.slice/kubelet.service
           ├─6709 /usr/bin/kubelet --allow-privileged=true --api-servers=https://10.240.0.21:6443,https://10.240.0.22:6443,https://10.240.0.2...
           └─6738 journalctl -k -f

Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.355931    6709 volume_manager.go:216] Starting Kubelet Volume Manager
Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.360590    6709 factory.go:228] Registering Docker factory
Jul 14 09:46:28 worker1 kubelet[6709]: E0714 09:46:28.360933    6709 manager.go:240] Registration of the rkt container factory failed... refused
Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.361134    6709 factory.go:54] Registering systemd factory
Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.362014    6709 factory.go:86] Registering Raw factory
Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.362740    6709 manager.go:1072] Started watching for new ooms in manager
Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.363567    6709 oomparser.go:185] oomparser using systemd
Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.364246    6709 manager.go:281] Starting recovery of all containers
Jul 14 09:46:28 worker1 kubelet[6709]: I0714 09:46:28.454304    6709 manager.go:286] Recovery completed
Jul 14 09:46:33 worker1 kubelet[6709]: I0714 09:46:33.349758    6709 kubelet.go:2477] skipping pod synchronization - [Kubenet does no...PodCIDR]
Hint: Some lines were ellipsized, use -l to show in full.
kamran@worker1:~$ 
```

kube-proxy:
```
sudo sh -c 'echo "[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/usr/bin/kube-proxy \
  --master=https://10.240.0.21:6443 \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --proxy-mode=iptables \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/kube-proxy.service'
```

**note:** again we have IP of one of the controllers instead of IP of controllers' pool ? [todo]

```
kamran@worker1:~$ sudo systemctl daemon-reload
kamran@worker1:~$ sudo systemctl enable kube-proxy
Created symlink from /etc/systemd/system/multi-user.target.wants/kube-proxy.service to /etc/systemd/system/kube-proxy.service.
kamran@worker1:~$ sudo systemctl start kube-proxy
kamran@worker1:~$ sudo systemctl status kube-proxy --no-pager
● kube-proxy.service - Kubernetes Kube Proxy
   Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; vendor preset: enabled)
   Active: activating (auto-restart) (Result: exit-code) since Thu 2016-07-14 09:49:48 UTC; 173ms ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
  Process: 6906 ExecStart=/usr/bin/kube-proxy --master=https://10.240.0.21:6443 --kubeconfig=/var/lib/kubelet/kubeconfig --proxy-mode=iptables --v=2 (code=exited, status=1/FAILURE)
 Main PID: 6906 (code=exited, status=1/FAILURE)

Jul 14 09:49:48 worker1 systemd[1]: kube-proxy.service: Main process exited, code=exited, status=1/FAILURE
Jul 14 09:49:48 worker1 systemd[1]: kube-proxy.service: Unit entered failed state.
Jul 14 09:49:48 worker1 systemd[1]: kube-proxy.service: Failed with result 'exit-code'.
kamran@worker1:~$ 
```

Failure! Why? (todo)


```
kamran@worker1:~$ journalctl -f
-- Logs begin at Wed 2016-07-13 10:58:49 UTC. --
Jul 14 09:51:22 worker1 systemd[1]: kube-proxy.service: Service hold-off time over, scheduling restart.
Jul 14 09:51:22 worker1 systemd[1]: Stopped Kubernetes Kube Proxy.
Jul 14 09:51:22 worker1 systemd[1]: Started Kubernetes Kube Proxy.
Jul 14 09:51:22 worker1 kube-proxy[7069]: I0714 09:51:22.463433    7069 server.go:154] setting OOM scores is unsupported in this build
Jul 14 09:51:22 worker1 kube-proxy[7069]: stat /var/lib/kubelet/kubeconfig: no such file or directory
Jul 14 09:51:22 worker1 systemd[1]: kube-proxy.service: Main process exited, code=exited, status=1/FAILURE
Jul 14 09:51:22 worker1 systemd[1]: kube-proxy.service: Unit entered failed state.
Jul 14 09:51:22 worker1 systemd[1]: kube-proxy.service: Failed with result 'exit-code'.
Jul 14 09:51:23 worker1 kubelet[6709]: I0714 09:51:23.410552    6709 kubelet.go:2477] skipping pod synchronization - [Kubenet does not have netConfig. This is most likely due to lack of PodCIDR]
Jul 14 09:51:24 worker1 sudo[7059]: pam_unix(sudo:session): session closed for user root
Jul 14 09:51:27 worker1 systemd[1]: kube-proxy.service: Service hold-off time over, scheduling restart.
Jul 14 09:51:27 worker1 systemd[1]: Stopped Kubernetes Kube Proxy.
Jul 14 09:51:27 worker1 systemd[1]: Started Kubernetes Kube Proxy.
Jul 14 09:51:27 worker1 kube-proxy[7077]: I0714 09:51:27.714602    7077 server.go:154] setting OOM scores is unsupported in this build
Jul 14 09:51:27 worker1 kube-proxy[7077]: stat /var/lib/kubelet/kubeconfig: no such file or directory
Jul 14 09:51:27 worker1 systemd[1]: kube-proxy.service: Main process exited, code=exited, status=1/FAILURE
Jul 14 09:51:27 worker1 systemd[1]: kube-proxy.service: Unit entered failed state.
Jul 14 09:51:27 worker1 systemd[1]: kube-proxy.service: Failed with result 'exit-code'.
Jul 14 09:51:28 worker1 kubelet[6709]: I0714 09:51:28.356308    6709 container_manager_linux.go:284] Discovered runtime cgroups name: /system.slice/docker.service
Jul 14 09:51:28 worker1 kubelet[6709]: I0714 09:51:28.411613    6709 kubelet.go:2477] skipping pod synchronization - [Kubenet does not have netConfig. This is most likely due to lack of PodCIDR]
^C
kamran@worker1:~$ 
``` 

OK, so I missed  a step to execute on worker node, which creates /var/lib/kubelet/kubeconfig. Recreated it and restarted service kube-proxy. All became OK.

```
kamran@worker1:~$ sudo systemctl status kube-proxy --no-pager
● kube-proxy.service - Kubernetes Kube Proxy
   Loaded: loaded (/etc/systemd/system/kube-proxy.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2016-07-14 09:53:27 UTC; 1min 10s ago
     Docs: https://github.com/GoogleCloudPlatform/kubernetes
 Main PID: 7397 (kube-proxy)
    Tasks: 6
   Memory: 5.4M
      CPU: 904ms
   CGroup: /system.slice/kube-proxy.service
           └─7397 /usr/bin/kube-proxy --master=https://10.240.0.21:6443 --kubeconfig=/var/lib/kubelet/kubeconfig --proxy-mode=iptables --v=2

Jul 14 09:53:27 worker1 systemd[1]: Started Kubernetes Kube Proxy.
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.577730    7397 server.go:154] setting OOM scores is unsupported in this build
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.584129    7397 server.go:201] Using iptables Proxier.
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.584600    7397 server.go:214] Tearing down userspace rules.
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.593516    7397 conntrack.go:36] Setting nf_conntrack_max to 262144
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.594381    7397 conntrack.go:41] Setting conntrack hashsize to 65536
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.594919    7397 conntrack.go:46] Setting nf_conntrack_tcp_timeout_established to 86400
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.635690    7397 proxier.go:502] Setting endpoints for "default/kubernetes:htt...23:6443]
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.636219    7397 proxier.go:647] Not syncing iptables until Services and Endpo...m master
Jul 14 09:53:27 worker1 kube-proxy[7397]: I0714 09:53:27.637706    7397 proxier.go:427] Adding new service "default/kubernetes:https"...:443/TCP
Hint: Some lines were ellipsized, use -l to show in full.
kamran@worker1:~$ 
```

```
kamran@worker1:~$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS               NAMES

kamran@worker1:~$ ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 42:01:0a:f0:00:1f brd ff:ff:ff:ff:ff:ff
    inet 10.240.0.31/32 brd 10.240.0.31 scope global ens4
       valid_lft forever preferred_lft forever
    inet6 fe80::4001:aff:fef0:1f/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:89:5b:bc:ea brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
kamran@worker1:~$ 
```


------


# Configuring the Kubernetes Client - Remote Access

## Linux
```
wget https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin
```


Configure the kubectl client to point to the Kubernetes API Server Frontend Load Balancer.
```
[kamran@kworkhorse ~]$ export KUBERNETES_PUBLIC_IP_ADDRESS=$(gcloud compute addresses describe kubernetes \
>   --format 'value(address)')

[kamran@kworkhorse ~]$ echo $KUBERNETES_PUBLIC_IP_ADDRESS 
130.211.80.214
[kamran@kworkhorse ~]$ 
```

Recall the token we setup for the admin user:
```
# /var/run/kubernetes/token.csv on the controller nodes
chAng3m3,admin,admin
```
Also be sure to locate the CA certificate created earlier. Since we are using self-signed TLS certs we need to trust the CA certificate so we can verify the remote API Servers.

## Build up the kubeconfig entry

The following commands will build up the default kubeconfig file used by kubectl.

```
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_PUBLIC_IP_ADDRESS}:6443


kubectl config set-credentials admin --token chAng3m3


kubectl config set-context default-context \
  --cluster=kubernetes-the-hard-way \
  --user=admin


kubectl config use-context default-context
```

Here is the same commands with their outputs:

```
[kamran@kworkhorse ~]$ kubectl config set-cluster kubernetes-the-hard-way \
>   --certificate-authority=ca.pem \
>   --embed-certs=true \
>   --server=https://${KUBERNETES_PUBLIC_IP_ADDRESS}:6443
cluster "kubernetes-the-hard-way" set.


[kamran@kworkhorse ~]$ kubectl config set-credentials admin --token chAng3m3
user "admin" set.


[kamran@kworkhorse ~]$ kubectl config set-context default-context \
>   --cluster=kubernetes-the-hard-way \
>   --user=admin
context "default-context" set.


[kamran@kworkhorse ~]$ kubectl config use-context default-context
switched to context "default-context".
[kamran@kworkhorse ~]$ 
```



At this point you should be able to connect securly to the remote API server:

```
[kamran@kworkhorse ~]$ kubectl get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-0               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}   
[kamran@kworkhorse ~]$ 
```

```
[kamran@kworkhorse ~]$ kubectl get nodes
NAME      STATUS    AGE
worker2   Ready     7m
worker3   Ready     7m
[kamran@kworkhorse ~]$ 
```

Where is worker1? (todo)

Rebooted worker1 and got it up:

```
[kamran@kworkhorse ~]$ kubectl get nodes
NAME      STATUS    AGE
worker1   Ready     1m
worker2   Ready     9m
worker3   Ready     9m
[kamran@kworkhorse ~]$ 
```

-------------

# Managing the Container Network Routes

Now that each worker node is online we need to add routes to make sure that Pods running on different machines can talk to each other. In this lab we are not going to provision any overlay networks and instead rely on Layer 3 networking. That means we need to add routes to our router. In GCP each network has a router that can be configured. If this was an on-prem datacenter then ideally you would need to add the routes to your local router.



The first thing we need to do is gather the information required to populate the router table. We need the Internal IP address and Pod Subnet for each of the worker nodes.
```
kubectl get nodes \
  --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
``` 

``` 
[kamran@kworkhorse ~]$ kubectl get nodes \
>   --output=jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address} {.spec.podCIDR} {"\n"}{end}'
10.240.0.31 10.200.2.0/24 
10.240.0.32 10.200.0.0/24 
10.240.0.33 10.200.1.0/24 
[kamran@kworkhorse ~]$ 
``` 


Next we see what does our routing table currently look like on GCE routers:

```
[kamran@kworkhorse ~]$ gcloud compute routes list --filter "network=kubernetes"
NAME                            NETWORK     DEST_RANGE     NEXT_HOP                  PRIORITY
default-route-34d2d73caf55cd54  kubernetes  10.240.0.0/24                            1000
default-route-3562cd5bbcf26afd  kubernetes  0.0.0.0/0      default-internet-gateway  1000
[kamran@kworkhorse ~]$ 
```

So we see that GCE/GCP does not know about any of the pod networks, which we saw a moment ago. So we need to udate google cloud with the routes of our pod CIDR networks. We use gcloud to manually add these routes to GCP:

```
gcloud compute routes create kubernetes-route-10-200-2-0-24 \
  --network kubernetes \
  --next-hop-address 10.240.0.31 \
  --destination-range 10.200.2.0/24

gcloud compute routes create kubernetes-route-10-200-0-0-24 \
  --network kubernetes \
  --next-hop-address 10.240.0.32 \
  --destination-range 10.200.0.0/24

gcloud compute routes create kubernetes-route-10-200-1-0-24 \
  --network kubernetes \
  --next-hop-address 10.240.0.33 \
  --destination-range 10.200.1.0/24
``` 


Now we check our routing table again:

```
[kamran@kworkhorse ~]$ gcloud compute routes list --filter "network=kubernetes"NAME                            NETWORK     DEST_RANGE     NEXT_HOP                  PRIORITY
default-route-34d2d73caf55cd54  kubernetes  10.240.0.0/24                            1000
default-route-3562cd5bbcf26afd  kubernetes  0.0.0.0/0      default-internet-gateway  1000
kubernetes-route-10-200-0-0-24  kubernetes  10.200.0.0/24  10.240.0.32               1000
kubernetes-route-10-200-1-0-24  kubernetes  10.200.1.0/24  10.240.0.33               1000
kubernetes-route-10-200-2-0-24  kubernetes  10.200.2.0/24  10.240.0.31               1000
[kamran@kworkhorse ~]$ 
```

------ 

We we setup DNS addon, we can do a test by deploying a nginx image with three replicas, to see what IP addresses does the pod get:


```
[kamran@kworkhorse ~]$ kubectl run nginx --image=nginx --port=80 --replicas=3
deployment "nginx" created
[kamran@kworkhorse ~]$ 

[kamran@kworkhorse ~]$ kubectl get pods -o wide
NAME                     READY     STATUS    RESTARTS   AGE       NODE
nginx-2032906785-35cdn   1/1       Running   0          36s       worker2
nginx-2032906785-c7n9u   1/1       Running   0          36s       worker3
nginx-2032906785-u2gg6   1/1       Running   0          36s       worker1
[kamran@kworkhorse ~]$ 

```
Surprisingly I do not see IP addresses of the pods in this output, whereas Kelsey's article shows pod IPs too! Anyway, lets see what IP address each pod has got:

```
[kamran@kworkhorse ~]$ kubectl exec nginx-2032906785-35cdn "ip" "addr"
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:c8:00:02 brd ff:ff:ff:ff:ff:ff
    inet 10.200.0.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::f88f:94ff:feb7:3e10/64 scope link 
       valid_lft forever preferred_lft forever
``` 

``` 
[kamran@kworkhorse ~]$ kubectl exec nginx-2032906785-c7n9u "ip" "addr"
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:c8:01:02 brd ff:ff:ff:ff:ff:ff
    inet 10.200.1.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::74c1:e7ff:fea8:7da5/64 scope link 
       valid_lft forever preferred_lft forever
``` 

``` 
[kamran@kworkhorse ~]$ kubectl exec nginx-2032906785-u2gg6 "ip" "addr"
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:c8:02:02 brd ff:ff:ff:ff:ff:ff
    inet 10.200.2.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::4c1b:8dff:fee0:3cbf/64 scope link 
       valid_lft forever preferred_lft forever
[kamran@kworkhorse ~]$ 

```

Todo: The node does not have these addresses defined on them, so how does a node know where to send an incoming packet for such as IP address? I see that a pod on one node can ping a pod on the other node!

```
root@nginx-2032906785-35cdn:/# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
3: eth0@if5: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue state UP group default 
    link/ether 0a:58:0a:c8:00:02 brd ff:ff:ff:ff:ff:ff
    inet 10.200.0.2/24 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::f88f:94ff:feb7:3e10/64 scope link 
       valid_lft forever preferred_lft forever

root@nginx-2032906785-35cdn:/# ping 10.200.1.2
PING 10.200.1.2 (10.200.1.2): 56 data bytes
64 bytes from 10.200.1.2: icmp_seq=0 ttl=62 time=1.186 ms
^C--- 10.200.1.2 ping statistics ---
1 packets transmitted, 1 packets received, 0% packet loss
round-trip min/avg/max/stddev = 1.186/1.186/1.186/0.000 ms
root@nginx-2032906785-35cdn:/# 
``` 

This is because each node has a local network for pods:

```
[kamran@kworkhorse ~]$ gcloud compute ssh worker1 "ip addr"
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 42:01:0a:f0:00:1f brd ff:ff:ff:ff:ff:ff
    inet 10.240.0.31/32 brd 10.240.0.31 scope global ens4
       valid_lft forever preferred_lft forever
    inet6 fe80::4001:aff:fef0:1f/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:a8:5b:86:9a brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
4: cbr0: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1460 qdisc htb state UP group default qlen 1000
    link/ether 62:73:c7:8a:ba:cd brd ff:ff:ff:ff:ff:ff
    inet 10.200.2.1/24 scope global cbr0
       valid_lft forever preferred_lft forever
    inet6 fe80::cf4:aff:fed5:c31b/64 scope link 
       valid_lft forever preferred_lft forever
5: veth71e2fe9a@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue master cbr0 state UP group default 
    link/ether 62:73:c7:8a:ba:cd brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::6073:c7ff:fe8a:bacd/64 scope link 
       valid_lft forever preferred_lft forever
[kamran@kworkhorse ~]$ 
``` 


```
[kamran@kworkhorse ~]$ gcloud compute ssh worker2 "ip addr"
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 42:01:0a:f0:00:20 brd ff:ff:ff:ff:ff:ff
    inet 10.240.0.32/32 brd 10.240.0.32 scope global ens4
       valid_lft forever preferred_lft forever
    inet6 fe80::4001:aff:fef0:20/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:34:5b:25:bc brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
4: cbr0: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1460 qdisc htb state UP group default qlen 1000
    link/ether e6:1e:67:76:b5:c4 brd ff:ff:ff:ff:ff:ff
    inet 10.200.0.1/24 scope global cbr0
       valid_lft forever preferred_lft forever
    inet6 fe80::4da:89ff:fe03:d11e/64 scope link 
       valid_lft forever preferred_lft forever
5: vethd1a195a0@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue master cbr0 state UP group default 
    link/ether e6:1e:67:76:b5:c4 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::e41e:67ff:fe76:b5c4/64 scope link 
       valid_lft forever preferred_lft forever
[kamran@kworkhorse ~]$ 
```


```
[kamran@kworkhorse ~]$ gcloud compute ssh worker3 "ip addr"
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: ens4: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 42:01:0a:f0:00:21 brd ff:ff:ff:ff:ff:ff
    inet 10.240.0.33/32 brd 10.240.0.33 scope global ens4
       valid_lft forever preferred_lft forever
    inet6 fe80::4001:aff:fef0:21/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:a5:70:14:5e brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 scope global docker0
       valid_lft forever preferred_lft forever
4: cbr0: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1460 qdisc htb state UP group default qlen 1000
    link/ether 9a:0c:0c:6e:48:59 brd ff:ff:ff:ff:ff:ff
    inet 10.200.1.1/24 scope global cbr0
       valid_lft forever preferred_lft forever
    inet6 fe80::c0b1:42ff:febb:73f3/64 scope link 
       valid_lft forever preferred_lft forever
5: vetha43e9d73@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1460 qdisc noqueue master cbr0 state UP group default 
    link/ether 9a:0c:0c:6e:48:59 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::980c:cff:fe6e:4859/64 scope link 
       valid_lft forever preferred_lft forever
[kamran@kworkhorse ~]$ 
```

Todo: How docker creates pods on cbr0 instead of docker0 ?




------ 
# DNS: Deploying the Cluster DNS Add-on

In this lab you will deploy the DNS add-on which is required for every Kubernetes cluster. Without the DNS add-on the following things will not work:

* DNS based service discovery
* DNS lookups from containers running in pods

## Cluster DNS Add-on

Create the skydns service:

``` 
kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/skydns-svc.yaml
``` 

Verify:

```
[kamran@kworkhorse ~]$ kubectl --namespace=kube-system get svc
NAME       CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kube-dns   10.32.0.10   <none>        53/UDP,53/TCP   29s
[kamran@kworkhorse ~]$ 
``` 

Create the skydns replication controller:

```
kubectl create -f https://raw.githubusercontent.com/kelseyhightower/kubernetes-the-hard-way/master/skydns-rc.yaml
```


Verify:
``` 
[kamran@kworkhorse ~]$ kubectl --namespace=kube-system get pods
NAME                 READY     STATUS    RESTARTS   AGE
kube-dns-v18-jus22   2/3       Running   0          10s
kube-dns-v18-nxvny   2/3       Running   0          10s
[kamran@kworkhorse ~]$ 
```

---------- 

# Smoke Test

This lab walks you through a quick smoke test to make sure things are working.


```
[kamran@kworkhorse ~]$ kubectl run nginx --image=nginx --port=80 --replicas=3
deployment "nginx" created


[kamran@kworkhorse ~]$ kubectl get pods -o wide
NAME                     READY     STATUS    RESTARTS   AGE       NODE
nginx-2032906785-00uoo   1/1       Running   0          7s        worker1
nginx-2032906785-4drom   1/1       Running   0          7s        worker2
nginx-2032906785-el26y   1/1       Running   0          7s        worker3


[kamran@kworkhorse ~]$ kubectl expose deployment nginx --type NodePort
service "nginx" exposed
[kamran@kworkhorse ~]$ 
```

**Note:** Note that --type=LoadBalancer will not work because we did not configure a cloud provider when bootstrapping this cluster.

Grab the NodePort that was setup for the nginx service:

```
[kamran@kworkhorse ~]$ export NODE_PORT=$(kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}')

[kamran@kworkhorse ~]$ echo $NODE_PORT 
31751
[kamran@kworkhorse ~]$
```

Now create a firewall rule in google cloud:
```
gcloud compute firewall-rules create kubernetes-nginx-service \
  --allow=tcp:${NODE_PORT} \
  --network kubernetes



[kamran@kworkhorse ~]$ gcloud compute firewall-rules create kubernetes-nginx-service \
>   --allow=tcp:${NODE_PORT} \
>   --network kubernetes
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/global/firewalls/kubernetes-nginx-service].
NAME                      NETWORK     SRC_RANGES  RULES      SRC_TAGS  TARGET_TAGS
kubernetes-nginx-service  kubernetes  0.0.0.0/0   tcp:31751
[kamran@kworkhorse ~]$ 
```

Grab the EXTERNAL_IP for one of the worker nodes:

``` 
export NODE_PUBLIC_IP=$(gcloud compute instances describe worker1 \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')
``` 

```
[kamran@kworkhorse ~]$ echo $NODE_PUBLIC_IP 
130.211.73.128
[kamran@kworkhorse ~]$
```

Test the nginx service using cURL from your local work computer:

``` 
curl http://${NODE_PUBLIC_IP}:${NODE_PORT}
``` 

And, It Works!

```
[kamran@kworkhorse ~]$ curl http://${NODE_PUBLIC_IP}:${NODE_PORT}
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
[kamran@kworkhorse ~]$ 
```

## Check DNS resolution on pods:

The default nginx image does not have any dns client tools in it. 

```
[kamran@kworkhorse ~]$ kubectl exec nginx-2032906785-00uoo -i -t -- "bash"

root@nginx-2032906785-00uoo:/# nslookup kubernetes
bash: nslookup: command not found
root@nginx-2032906785-00uoo:/# 
```

I tried to install nslookup or dig, but apt-get update fails. Apparently it was not able to resolve any names:

```
root@nginx-2032906785-00uoo:/# apt-get update
Err http://httpredir.debian.org jessie InRelease                               
  
Err http://httpredir.debian.org jessie-updates InRelease                       
  
Err http://security.debian.org jessie/updates InRelease                        
  
Err http://nginx.org jessie InRelease                                          
  
Err http://httpredir.debian.org jessie Release.gpg                             
  Could not resolve 'httpredir.debian.org'
Err http://security.debian.org jessie/updates Release.gpg
  Could not resolve 'security.debian.org'
Err http://nginx.org jessie Release.gpg
  Could not resolve 'nginx.org'
Err http://httpredir.debian.org jessie-updates Release.gpg
  Could not resolve 'httpredir.debian.org'
Reading package lists... Done
W: Failed to fetch http://httpredir.debian.org/debian/dists/jessie/InRelease  

W: Failed to fetch http://httpredir.debian.org/debian/dists/jessie-updates/InRelease  

W: Failed to fetch http://security.debian.org/dists/jessie/updates/InRelease  

W: Failed to fetch http://nginx.org/packages/mainline/debian/dists/jessie/InRelease  

W: Failed to fetch http://httpredir.debian.org/debian/dists/jessie/Release.gpg  Could not resolve 'httpredir.debian.org'

W: Failed to fetch http://httpredir.debian.org/debian/dists/jessie-updates/Release.gpg  Could not resolve 'httpredir.debian.org'

W: Failed to fetch http://security.debian.org/dists/jessie/updates/Release.gpg  Could not resolve 'security.debian.org'

W: Failed to fetch http://nginx.org/packages/mainline/debian/dists/jessie/Release.gpg  Could not resolve 'nginx.org'

W: Some index files failed to download. They have been ignored, or old ones used instead.
root@nginx-2032906785-00uoo:/# 

``` 

Though the resolv.conf file on the nginx pod has the DNS entry and looks like this:
```
root@nginx-2032906785-00uoo:/# cat /etc/resolv.conf 
search default.svc.cluster.local svc.cluster.local cluster.local c.learn-kubernetes-1289.internal google.internal
nameserver 10.32.0.10
options ndots:5
root@nginx-2032906785-00uoo:/# 
```


I have a custom image I use for such troubleshooting. I used that and found out that DNS server is not reachable.

```
[kamran@kworkhorse ~]$ kubectl run centos-multitool --image=kamranazeem/centos-multitool --replicas=1
deployment "centos-multitool" created

[kamran@kworkhorse ~]$ kubectl get pods
NAME                                READY     STATUS    RESTARTS   AGE
centos-multitool-3822887632-pwlr1   1/1       Running   0          11s
nginx-2032906785-00uoo              1/1       Running   0          20h
nginx-2032906785-4drom              1/1       Running   0          20h
nginx-2032906785-el26y              1/1       Running   0          20h


[kamran@kworkhorse ~]$ kubectl exec centos-multitool-3822887632-pwlr1  -i -t -- "bash"

[root@centos-multitool-3822887632-pwlr1 /]# dig yahoo.com

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> yahoo.com
;; global options: +cmd
;; connection timed out; no servers could be reached

[root@centos-multitool-3822887632-pwlr1 /]# cat /etc/resolv.conf 
search default.svc.cluster.local svc.cluster.local cluster.local c.learn-kubernetes-1289.internal google.internal
nameserver 10.32.0.10
options ndots:5

[root@centos-multitool-3822887632-pwlr1 /]# dig yahoo.com @10.32.0.10

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> yahoo.com @10.32.0.10
;; global options: +cmd
;; connection timed out; no servers could be reached
[root@centos-multitool-3822887632-pwlr1 /]# 
```

I checked the name resolution from a worker, using cluster DNS, and it works:

```
kamran@worker3:~$ dig yahoo.com @10.32.0.10

; <<>> DiG 9.10.3-P4-Ubuntu <<>> yahoo.com @10.32.0.10
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 53713
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;yahoo.com.			IN	A

;; ANSWER SECTION:
yahoo.com.		1799	IN	A	98.139.183.24
yahoo.com.		1799	IN	A	98.138.253.109
yahoo.com.		1799	IN	A	206.190.36.45

;; Query time: 37 msec
;; SERVER: 10.32.0.10#53(10.32.0.10)
;; WHEN: Fri Jul 15 10:13:46 UTC 2016
;; MSG SIZE  rcvd: 86

kamran@worker3:~$ 
```

You may want to check this issue: [https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/33](https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/33)

So, maybe it is a firewall thing, which is not letting the pods access the DNS service? I created a (very open) firewall rule to allow DNS traffic:

```
[kamran@kworkhorse ~]$ gcloud compute firewall-rules create kubernetes-allow-dns \
>   --allow tcp:53,udp:53 \
>   --network kubernetes \
>   --source-ranges 0.0.0.0/0
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/global/firewalls/kubernetes-allow-dns].
NAME                  NETWORK     SRC_RANGES  RULES          SRC_TAGS  TARGET_TAGS
kubernetes-allow-dns  kubernetes  0.0.0.0/0   tcp:53,udp:53
[kamran@kworkhorse ~]$ 
```  

And now it works! 

```
[kamran@kworkhorse ~]$ kubectl exec centos-multitool-3822887632-pwlr1  -i -t -- "bash"
[root@centos-multitool-3822887632-pwlr1 /]# dig yahoo.com

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> yahoo.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 5006
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;yahoo.com.			IN	A

;; ANSWER SECTION:
yahoo.com.		1249	IN	A	206.190.36.45
yahoo.com.		1249	IN	A	98.138.253.109
yahoo.com.		1249	IN	A	98.139.183.24

;; Query time: 3 msec
;; SERVER: 10.32.0.10#53(10.32.0.10)
;; WHEN: Fri Jul 15 10:22:56 UTC 2016
;; MSG SIZE  rcvd: 86

[root@centos-multitool-3822887632-pwlr1 /]# 
```

```
[root@centos-multitool-3822887632-pwlr1 /]# dig kubernetes.default.svc.cluster.local                   

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> kubernetes.default.svc.cluster.local
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 61700
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;kubernetes.default.svc.cluster.local. IN A

;; ANSWER SECTION:
kubernetes.default.svc.cluster.local. 13 IN A	10.32.0.1

;; Query time: 2 msec
;; SERVER: 10.32.0.10#53(10.32.0.10)
;; WHEN: Fri Jul 15 10:23:48 UTC 2016
;; MSG SIZE  rcvd: 81

[root@centos-multitool-3822887632-pwlr1 /]# 
```


Furthermore, I tried to secure it a bit, by recreating this firewall rule only for the pod networks:
```
[kamran@kworkhorse ~]$ gcloud compute firewall-rules delete kubernetes-allow-dns   
The following firewalls will be deleted:
 - [kubernetes-allow-dns]

Do you want to continue (Y/n)?  y

Deleted [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/global/firewalls/kubernetes-allow-dns].

[kamran@kworkhorse ~]$
```

```
[kamran@kworkhorse ~]$ gcloud compute firewall-rules create kubernetes-allow-dns   --allow tcp:53,udp:53   --network kubernetes   --source-ranges 10.200.0.0/16
Created [https://www.googleapis.com/compute/v1/projects/learn-kubernetes-1289/global/firewalls/kubernetes-allow-dns].
NAME                  NETWORK     SRC_RANGES     RULES          SRC_TAGS  TARGET_TAGS
kubernetes-allow-dns  kubernetes  10.200.0.0/16  tcp:53,udp:53
[kamran@kworkhorse ~]$ 
```

Lets see if the DNS still works from a pod!

```
[kamran@kworkhorse ~]$ kubectl exec centos-multitool-3822887632-pwlr1  -i -t -- "bash"
[root@centos-multitool-3822887632-pwlr1 /]# dig yahoo.com 

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> yahoo.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 43623
;; flags: qr rd ra; QUERY: 1, ANSWER: 3, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;yahoo.com.			IN	A

;; ANSWER SECTION:
yahoo.com.		968	IN	A	98.139.183.24
yahoo.com.		968	IN	A	206.190.36.45
yahoo.com.		968	IN	A	98.138.253.109

;; Query time: 4 msec
;; SERVER: 10.32.0.10#53(10.32.0.10)
;; WHEN: Fri Jul 15 10:27:37 UTC 2016
;; MSG SIZE  rcvd: 86

[root@centos-multitool-3822887632-pwlr1 /]# dig kubernetes.default.svc.cluster.local      

; <<>> DiG 9.9.4-RedHat-9.9.4-29.el7_2.3 <<>> kubernetes.default.svc.cluster.local
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 52286
;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;kubernetes.default.svc.cluster.local. IN A

;; ANSWER SECTION:
kubernetes.default.svc.cluster.local. 21 IN A	10.32.0.1

;; Query time: 2 msec
;; SERVER: 10.32.0.10#53(10.32.0.10)
;; WHEN: Fri Jul 15 10:27:40 UTC 2016
;; MSG SIZE  rcvd: 81

[root@centos-multitool-3822887632-pwlr1 /]# 
```

It works! Hurray!



--------- 

# Cleanup. Remove everything.

[https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/10-cleanup.md](https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/10-cleanup.md)

