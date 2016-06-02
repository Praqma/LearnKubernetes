# Kubernetes-on-Fedora-Atomic-on-KVM

This Howto is an attempt to replicate a would-be bare-metal installation. This is done on KVM (not on AWS or GCE).

* Our domain for infrastructure hosts: example.com
* kube-master 192.168.124.10
* kube-node1: 192.168.124.11
* kube-node2: 192.168.124.12


Following : [http://www.projectatomic.io/docs/quickstart/](http://www.projectatomic.io/docs/quickstart/)

## Login problem
The login to console still does not work properly, even though we have password stored in the user-data file in cloud-init. However since I put my SSH key in it, it is able to login through SSH. Though I have to find the IP address it obtained from the network.

TODO: Improve console login, using: 
* [https://coreos.com/os/docs/latest/cloud-config.html](https://coreos.com/os/docs/latest/cloud-config.html)
* [https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting](https://www.digitalocean.com/community/tutorials/an-introduction-to-cloud-config-scripting)

```
[root@kworkhorse ~]# nmap -sP 192.168.124.0/24

Starting Nmap 7.12 ( https://nmap.org ) at 2016-06-02 14:09 CEST
Nmap scan report for 192.168.124.58
Host is up (0.00019s latency).
MAC Address: 52:54:00:05:BB:EA (QEMU virtual NIC)
Nmap scan report for 192.168.124.1
Host is up.
Nmap done: 256 IP addresses (2 hosts up) scanned in 2.54 seconds
[root@kworkhorse ~]# 
```

```
[kamran@kworkhorse fedora-atomic-cloud-init]$ ssh fedora@192.168.124.58
The authenticity of host '192.168.124.58 (192.168.124.58)' can't be established.
ECDSA key fingerprint is SHA256:Z619UHp/qO+N6Fk9AFumxaKtt9G0VV8peFzTu+yyzyQ.
ECDSA key fingerprint is MD5:af:a7:66:84:aa:8b:8f:9d:3a:fb:4a:dd:c6:b0:28:c6.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.124.58' (ECDSA) to the list of known hosts.
[fedora@localhost ~]$ 
``` 

After, logging in through SSH, I notice that the password to fedora is not assigned:

```
[fedora@localhost ~]$ sudo -i
-bash-4.3# cat /etc/shadow

root:!locked::0:99999:7:::
bin:*:16854:0:99999:7:::
daemon:*:16854:0:99999:7:::
adm:*:16854:0:99999:7:::
lp:*:16854:0:99999:7:::
sync:*:16854:0:99999:7:::
shutdown:*:16854:0:99999:7:::
halt:*:16854:0:99999:7:::
mail:*:16854:0:99999:7:::
operator:*:16854:0:99999:7:::
games:*:16854:0:99999:7:::
ftp:*:16854:0:99999:7:::
nobody:*:16854:0:99999:7:::
fedora:!!:16954:0:99999:7:::
-bash-4.3# 
```

Anyway, moving on.

# Prepare host:
* Assign proper hostname (kube-master.example.com)
* Assign proper IP (192.168.124.10)
* Disable SELinux (/etc/selinux/config)
* Update OS (# rpm-ostree upgrade)
* Optional: Change boot order in KVM. (Not necessary). Note: DO NOT remove CDROM device. (This will result in the node taking too long to boot - at all !)
* Reboot


# Setup Kubernetes related services on Master and worker nodes


