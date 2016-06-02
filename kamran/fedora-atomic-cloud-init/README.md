Refernce: http://www.projectatomic.io/docs/quickstart/
Use the files to create a cloud init ISO for the atomic qcow2 images. Without this, the even if you import the Fedora Atomic qcow2 images, you will not have username / password. So!

Generate the image using:
```
# genisoimage -output init.iso -volid cidata -joliet -rock user-data meta-data
```

Note: You must use filenames for above files as user-data and meta-data. If you give them different names,you will have issues when Atomic host starts. cloud-init expect user-data and meta-data as input filenames. You can learn more about this if you check cloud-init code at cloud-init-github.

The files look like this:

```
$ cat meta-data 
instance-id: 
local-hostname: 
```
You can have instance ID and hostnames in this file, or you can opt not to have. It is upto you.


```
$ cat user-data 
#cloud-config
password: atomic
chpasswd: {expire: False}
ssh_pwauth: True
ssh_authorized_keys:
  - <enter here your public key from ~/.ssh/id_rsa.pub
```

Note: #cloud-config in user-data is actually a directive, not a comment. The default user is fedora, and the password for this user is mentioned in this file (user-data).


I created the iso image:
```
genisoimage -output /home/cdimages/fedora-cloud-init-kubernetes.iso -volid cidata -joliet -rock user-data meta-data 
```

Generated file will look like this:
```
[kamran@kworkhorse ~]$ ls /home/cdimages/ -lh
total 5.5G
-rw-rw-r-- 1 kamran kamran 477M Jun  2 10:33 Fedora-Cloud-Atomic-23-20160524.x86_64.qcow2
-rw-rw-r-- 1 kamran kamran 366K Jun  2 13:19 fedora-cloud-init-kubernetes.iso
[kamran@kworkhorse ~]$ 
```

Note: Make sure that you copy the qcow2 images into your "virtualmachines" dierctory with a copy of each host you intend to use.

```
[root@kworkhorse ~]# ls -lh /home/virtualmachines/
total 3.2G
-rw-rw-r-- 1 kamran kamran 477M Jun  2 10:33 Kube-Master.qcow2
-rw-rw-r-- 1 kamran kamran 477M Jun  2 10:33 Kube-Node1.qcow2
-rw-rw-r-- 1 kamran kamran 477M Jun  2 10:33 Kube-Node2.qcow2
[root@kworkhorse ~]# 
```


Note: I have not adjusted the permissions for these files in this README, but you may need to do that.
