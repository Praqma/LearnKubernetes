This directory contains some basic tools needed for easier management of the cluster.

# get-fingerprints.sh

Normally, when you connect some computer over SSH, you are presented with it's fingerprint. You normally press 'yes' to accept the fingerprint to be added to your known_hosts file; and then you get on to your usual business. The first time you connect you encounter something like this:

```
[kamran@kworkhorse ~]$ ssh root@192.168.124.200
The authenticity of host '192.168.124.200 (192.168.124.200)' can't be established.
ECDSA key fingerprint is SHA256:bRrm8pYvfO6r4xFnwQ7bwpZl9WgmqlDIDqkP214DqKM.
ECDSA key fingerprint is MD5:a5:a6:dd:13:d2:c4:39:15:32:4c:ae:17:6e:40:94:ea.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.124.200' (ECDSA) to the list of known hosts.
Last login: Mon Dec 12 11:29:37 2016 from 192.168.124.1
[root@dockerhost ~]# 
```
In case you re-provisioned the target computer, it's fingerprint changes. The fingerprint also changes if someone tries to portray that it is `192.168.124.200` instead of your machine. This is exactly where the fingerprint helps. So you should not blindly type 'yes'. 

Anyhow, assuming you simply re-provisioned 192.168.124.200 and when you try to ssh again, you encounter this message:

```
[kamran@kworkhorse ~]$ ssh root@192.168.124.200
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
IT IS POSSIBLE THAT SOMEONE IS DOING SOMETHING NASTY!
Someone could be eavesdropping on you right now (man-in-the-middle attack)!
It is also possible that a host key has just been changed.
The fingerprint for the ECDSA key sent by the remote host is
SHA256:3mdbjLQvVgkJIGM/ezDAMLdu4TqCGMAmXhVroiXux5o.
Please contact your system administrator.
Add correct host key in /home/kamran/.ssh/known_hosts to get rid of this message.
Offending ECDSA key in /home/kamran/.ssh/known_hosts:190
ECDSA host key for 192.168.124.200 has changed and you have requested strict checking.
Host key verification failed.
[kamran@kworkhorse ~]$ 
```

Normally you edit the known_hosts file in your home/.ssh directory, remove the offending entry, and try to connect again, which presents you with the fingerprint of the remote machine, you accept, and life moves on.

Assume you have 10 or 20 or 100 machines, a cluster, such as a kubernetes cluster, and you just reprovisioned new test cluster. The names and IP scheme are still the same but the fingerprints of all nodes have changed. Would you edit the known_hosts file and remove all entries manually? I suggest you do not, and use the `get-fingerprints.sh` script to get this task. 

The `get-fingerprints.sh` does two things. It picks your hosts file, scans your known_hosts file and removes all the entries based on what it finds in the hosts file. (**Note:** This is specially in context to kubernetes cluster) . Then, it does an ssh-keyscan on all the nodes and adds them to your known_hosts. Simple! 


 
