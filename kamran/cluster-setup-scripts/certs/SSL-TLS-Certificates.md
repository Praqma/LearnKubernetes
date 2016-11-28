# Generating certificates for all kubernetes nodes:

External IP (EC2)) = 52.220.203.49

```
export KUBERNETES_PUBLIC_IP_ADDRESS=52.220.203.49
```


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
```


```
openssl x509 -in ca.pem -text -noout
```



```
cat > kubernetes-csr.json <<EOF
{
  "CN": "*.example.com",
  "hosts": [
    "10.32.0.1",
    "etcd1",
    "etcd2",
    "etcd3",
    "etcd1.example.com",
    "etcd2.example.com",
    "etcd3.example.com",
    "controller1",
    "controller2",
    "controller",
    "controller1.example.com",
    "controller2.example.com",
    "controller.example.com",
    "worker1",
    "worker2",
    "worker3",
    "worker4",
    "worker1.example.com",
    "worker2.example.com",
    "worker3.example.com",
    "worker4.example.com",
    "lb1.example.com",
    "lb2.example.com",
    "lb.example.com",
    "172.32.10.43",
    "172.32.10.61",
    "172.32.10.70",
    "172.32.10.84",
    "172.32.10.73",
    "172.32.10.239",
    "172.32.10.162",
    "172.32.10.40",
    "172.32.10.50",
    "172.32.10.105",
    "172.32.10.68",
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


```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes
```


```
openssl x509 -in kubernetes.pem -text -noout
```


```
[kamran@kworkhorse aws]$ openssl x509 -in kubernetes.pem -text -noout
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            72:ad:e0:72:3e:7c:ed:93:ca:63:8f:7a:b4:e0:0b:f9:3d:54:37:a8
    Signature Algorithm: sha256WithRSAEncryption
        Issuer: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=CA, CN=Kubernetes
        Validity
            Not Before: Nov  9 09:09:00 2016 GMT
            Not After : Nov  9 09:09:00 2017 GMT
        Subject: C=NO, ST=Oslo, L=Oslo, O=Kubernetes, OU=Cluster, CN=*.example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:b6:e6:b8:ec:04:32:9d:d3:de:65:4a:ab:33:b2:
                    b3:c8:ff:64:4d:07:a7:f6:c8:55:c1:5b:3e:bd:03:
                    7c:b8:d9:95:3a:d3:83:fe:ce:6d:d3:14:d6:8c:92:
                    d0:ac:b2:c5:f0:26:0e:8d:b4:19:4c:2b:72:e7:de:
                    16:55:38:f9:6f:a9:5b:d8:5d:49:bd:75:38:eb:36:
                    e5:4a:ed:1c:a8:c7:ca:91:91:85:fc:a4:8b:47:60:
                    0f:4b:26:7e:f5:6f:18:72:40:10:51:0b:df:ec:69:
                    78:c6:fb:55:7c:57:24:b4:1d:b5:e9:fe:9e:53:dd:
                    23:90:e5:ef:0a:22:87:f6:e4:97:88:ee:05:7b:6a:
                    10:7c:af:6e:92:9a:77:6c:5d:4a:6e:0d:9a:be:21:
                    a1:f6:f9:6f:ed:8d:d2:11:22:98:1d:a8:35:34:4c:
                    fc:20:d3:c6:85:77:ca:a3:f6:c2:11:1a:6f:4e:d6:
                    bb:38:f4:48:ef:1d:4c:bc:fe:f3:a2:cd:9d:1d:5d:
                    1c:54:9f:c3:32:f9:60:d1:33:6f:02:0c:e0:6b:67:
                    27:4d:d3:4e:01:a5:f1:66:b1:16:fa:3a:14:32:c4:
                    db:18:7a:1c:84:26:b2:30:40:cd:20:7d:04:ab:14:
                    d5:7e:e6:f0:1c:7a:49:23:b8:9e:99:f1:04:27:20:
                    0f:2b
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Key Usage: critical
                Digital Signature, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication, TLS Web Client Authentication
            X509v3 Basic Constraints: critical
                CA:FALSE
            X509v3 Subject Key Identifier: 
                23:2C:0B:2A:CC:AB:85:89:15:AE:E3:51:21:B9:45:38:FA:D1:08:C7
            X509v3 Authority Key Identifier: 
                keyid:DE:4F:5E:4A:27:F8:9C:12:C4:3B:E4:CB:02:6D:AA:82:0D:CF:36:B5

            X509v3 Subject Alternative Name: 
                DNS:etcd1, DNS:etcd2, DNS:etcd3, DNS:etcd1.example.com, DNS:etcd2.example.com, DNS:etcd3.example.com, DNS:controller1, DNS:controller2, DNS:controller, DNS:controller1.example.com, DNS:controller2.example.com, DNS:controller.example.com, DNS:worker1, DNS:worker2, DNS:worker3, DNS:worker4, DNS:worker1.example.com, DNS:worker2.example.com, DNS:worker3.example.com, DNS:worker4.example.com, DNS:lb1.example.com, DNS:lb2.example.com, DNS:lb.example.com, DNS:kubernetes.example.com, DNS:localhost, IP Address:10.32.0.1, IP Address:52.220.203.49, IP Address:127.0.0.1
    Signature Algorithm: sha256WithRSAEncryption
         5f:8e:44:bc:77:7d:21:15:5b:5c:c6:8f:eb:77:8e:77:ce:95:
         5f:88:b6:60:b2:e0:9e:69:0b:6b:79:89:b8:dd:3d:6e:27:2f:
         0d:ef:40:f3:21:aa:fa:d1:4e:38:45:b1:1c:ba:8b:0a:01:f6:
         7e:ad:f7:23:28:ed:47:e6:ce:ff:3f:60:f0:ef:fb:f1:f8:0b:
         49:a9:80:d6:8c:a7:bf:05:65:da:53:9f:72:b4:2a:d1:08:82:
         9c:39:c1:b0:8b:bc:c4:d8:ff:50:ce:f4:9c:40:30:ad:8d:39:
         bf:cb:dc:e5:7c:e6:54:5e:98:cf:04:1c:b0:17:89:5b:b7:58:
         c4:74:79:6c:44:0c:b9:ad:d4:54:ad:c1:f5:18:a1:aa:d6:4b:
         db:fc:16:72:5e:9c:8c:70:06:93:22:8d:c5:2b:49:f2:e5:44:
         3a:1a:a4:e5:57:e1:a8:57:70:fb:f6:9d:32:2f:bb:12:e8:e8:
         59:76:01:0e:a9:d6:cd:c9:1e:00:07:71:95:f1:10:5d:25:3a:
         ab:bd:e6:60:55:5c:da:b1:7f:45:0f:ae:2a:9a:1c:8e:97:4b:
         70:48:2e:f6:ba:12:f0:89:60:1b:9d:4e:c4:7e:9a:87:91:b1:
         1b:b7:f7:73:d9:44:77:e8:c3:82:39:f7:f2:df:64:2f:67:10:
         fd:21:50:6b
[kamran@kworkhorse aws]$ 
```


Lets copy these to the nodes:

```
chmod 0600 *.pem
for node in $(cat tfhosts.txt| cut -f1 -d$'\t' ); do 
  echo $node
  scp *.pem root@${node}:/root/ 
  echo "----------------"
done
```



```
for node in $(cat tfhosts.txt | grep etcd | cut -f1 -d$'\t' ); do
  echo $node
  ssh root@${node} "mkdir -p /etc/etcd/; mv ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/; chmod 0600 /etc/etcd/*.pem"
done
```


