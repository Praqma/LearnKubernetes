# High Availability using Pacemaker, Corosync and PCS

We have two (Fedora 24) nodes running web service. We want to make it highly available, by making it a HA cluster, using pacemaker.

Reference: [http://clusterlabs.org/doc/en-US/Pacemaker/1.1-pcs/html/Clusters_from_Scratch](http://clusterlabs.org/doc/en-US/Pacemaker/1.1-pcs/html/Clusters_from_Scratch)

# Setup:

**Note:** All steps performed as user root.


The IP addresses and hostnames are as follows. The /etc/hosts file should look like this on all cluster nodes.
```
 # cat /etc/hosts

127.0.0.1	localhost.localdomain	localhost
192.168.124.51	ha-web1.example.com	ha-web1
192.168.124.52	ha-web2.example.com	ha-web2
192.168.124.50	ha-web.example.com	ha-web
```

Install nginx pacemaker, corosync and pcs on both nodes:

``` 
yum -y install pacemaker corosync pcs psmisc nginx 
```

**Important:** Disable SELINUX and FirewallD on both nodes.


# Configuration:

# Enable PCS Daemon (pcsd):

Before the any other components of the cluster can be configured, the pcs daemon must be started and enabled to start at boot time on each node. This daemon works with the pcs command-line interface to manage synchronizing the corosync configuration across all nodes in the cluster.
Start and enable the daemon by issuing the following commands on each node:

```
systemctl start pcsd.service

systemctl enable pcsd.service
```

Verify that PCS daemon is running:
```
[root@ha-web1 ~]# systemctl status  pcsd.service
● pcsd.service - PCS GUI and remote configuration interface
   Loaded: loaded (/usr/lib/systemd/system/pcsd.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-10-28 12:05:00 CEST; 15s ago
 Main PID: 1532 (ruby-mri)
   CGroup: /system.slice/pcsd.service
           └─1532 /usr/bin/ruby-mri /usr/lib/pcsd/pcsd > /dev/null &

Oct 28 12:05:00 ha-web1.example.com systemd[1]: Starting PCS GUI and remote configuration interface...
Oct 28 12:05:00 ha-web1.example.com systemd[1]: Started PCS GUI and remote configuration interface.
[root@ha-web1 ~]# 
```

```
[root@ha-web2 ~]# systemctl status pcsd.service
● pcsd.service - PCS GUI and remote configuration interface
   Loaded: loaded (/usr/lib/systemd/system/pcsd.service; enabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-10-28 12:05:05 CEST; 1min 8s ago
 Main PID: 1358 (ruby-mri)
   CGroup: /system.slice/pcsd.service
           └─1358 /usr/bin/ruby-mri /usr/lib/pcsd/pcsd > /dev/null &

Oct 28 12:05:04 ha-web2.example.com systemd[1]: Starting PCS GUI and remote configuration interface...
Oct 28 12:05:05 ha-web2.example.com systemd[1]: Started PCS GUI and remote configuration interface.
[root@ha-web2 ~]# 
```


The installed packages will create a user named `hacluster` with a disabled password. 

```
[root@ha-web1 ~]# grep hacluster /etc/passwd /etc/shadow
/etc/passwd:hacluster:x:189:189:cluster user:/home/hacluster:/sbin/nologin
/etc/shadow:hacluster:!!:17101::::::
[root@ha-web1 ~]# 
```

This user account needs a password in order to perform tasks - such as: syncing the corosync configuration, or starting and stopping the cluster on other nodes. Since this tutorial will make use of such (pcs) commands, we nee to set a password for the hacluster user; ensuring to use the same password on both nodes.

I use the password **redhat** for the user **hacluster** for this tutorial, as this is just an example cluster. You should definitely use a stronger password for production system.

Execute the following on both nodes:
```
echo "hacluster:redhat" | chpasswd
```

Verify that the user `hacluster` can be used to talk to both nodes, using the pcs commands:

```
[root@ha-web1 ~]# pcs cluster auth ha-web1.example.com  ha-web2.example.com 
Username: hacluster
Password: 
ha-web1.example.com: Authorized
ha-web2.example.com: Authorized
[root@ha-web1 ~]# 
```

You must be able to see **Authorized** appearing for both nodes.

**Note:** This *authentication*, when successful, will survive reboots. So you only need to do once. Doing it twice does not harm. e.g. After a reboot, I tried it and got the following, which is okay!

```
[root@ha-web1 ~]# pcs cluster auth ha-web1.example.com  ha-web2.example.com 
ha-web1.example.com: Already authorized
ha-web2.example.com: Already authorized
[root@ha-web1 ~]# 
```

Doing so on the other node will give the following output:

```
[root@ha-web2 ~]# pcs cluster auth ha-web1.example.com ha-web2.example.com
ha-web1.example.com: Already authorized
ha-web2.example.com: Already authorized
[root@ha-web2 ~]# 
```

**Note:**  The auth command authenticates `pcs` to `pcsd` (pcs daemon) on specified nodes. If no nodes are specified, then it (the `pcs` command) authenticates to `pcsd` on all nodes specified in `corosync.conf` . The authorization tokens are stored in `~/.pcs/tokens` ; or `/var/lib/pcsd/tokens` for root user.

```
[root@ha-web1 ~]# cat /var/lib/pcsd/tokens
{
  "format_version": 2,
  "data_version": 6,
  "tokens": {
    "ha-web1.example.com": "d79d8c34-68be-4151-8715-c1422f82473d",
    "ha-web2.example.com": "59559227-edd9-4c25-8a48-4b7593922fe1"
  }
}
[root@ha-web1 ~]# 
```


```
[root@ha-web2 ~]# cat  /var/lib/pcsd/tokens 
{
  "format_version": 2,
  "data_version": 1,
  "tokens": {
    "ha-web1.example.com": "842cec81-ffb8-4502-8da9-4b23dc2d0c64",
    "ha-web2.example.com": "8c34c084-f852-48c8-a7a9-f29254e50c6a"
  }
}
[root@ha-web2 ~]# 
```

------

## CoroSync

We use `pcs cluster setup` command on the same node we authenticated from (ha-web1) - to generate and synchronize the corosync configuration on all cluster nodes. 

**Note:** It is important to authenticate to the nodes first, which we already did as a (last) verification step in the previous section.

Do this on ha-web1 only:
```
pcs cluster setup --name mywebcluster ha-web1.example.com ha-web2.example.com
```

You may get the following output:
```
[root@ha-web1 ~]# pcs cluster setup --name mywebcluster ha-web1.example.com ha-web2.example.com
Error: ha-web1.example.com: node is already in a cluster
Error: ha-web2.example.com: node is already in a cluster
Error: nodes availability check failed, use --force to override. WARNING: This will destroy existing cluster on the nodes.
[root@ha-web1 ~]# 
```

In that case, just use the --force option to re-create the cluster. (todo: why it fails? is it because I already setup corosync services . But I deleted corosync confs and stopped corosync and pacemaker on both nodes before using the cluster setup command !)

```
[root@ha-web1 ~]# pcs cluster setup --name mywebcluster ha-web1.example.com ha-web2.example.com --force
Destroying cluster on nodes: ha-web1.example.com, ha-web2.example.com...
ha-web1.example.com: Stopping Cluster (pacemaker)...
ha-web2.example.com: Stopping Cluster (pacemaker)...
ha-web1.example.com: Successfully destroyed cluster
ha-web2.example.com: Successfully destroyed cluster

Sending cluster config files to the nodes...
ha-web1.example.com: Succeeded
ha-web2.example.com: Succeeded

Synchronizing pcsd certificates on nodes ha-web1.example.com, ha-web2.example.com...
ha-web2.example.com: Success
ha-web1.example.com: Success

Restarting pcsd on the nodes in order to reload the certificates...
ha-web2.example.com: Success
ha-web1.example.com: Success
[root@ha-web1 ~]# 
```

**Note:** If you received an authorization error for either of those commands, make sure you configured the hacluster user account on each node with the same password.


You should see the following in the system logs:
```
[root@ha-web1 ~]# journalctl -u pcsd
-- Logs begin at Thu 2016-10-27 13:35:44 CEST, end at Fri 2016-10-28 13:01:01 CEST. --
Oct 28 12:45:10 ha-web1.example.com systemd[1]: Stopping PCS GUI and remote configuration interface...
Oct 28 12:45:10 ha-web1.example.com systemd[1]: Stopped PCS GUI and remote configuration interface.
Oct 28 12:45:10 ha-web1.example.com systemd[1]: Starting PCS GUI and remote configuration interface...
Oct 28 12:45:10 ha-web1.example.com systemd[1]: Started PCS GUI and remote configuration interface.
[root@ha-web1 ~]#
```

You should be able to get the status about pcsd through `pcs status pcsd` command:

```
[root@ha-web1 ~]# pcs status pcsd
  ha-web1.example.com: Online
  ha-web2.example.com: Online
[root@ha-web1 ~]# 
```



When the cluster is created (setup) as a result of the above pcs command, you should have freshly generated corosync config file (`/etc/corososync/corosync.conf`) on both nodes.

```
[root@ha-web1 ~]# cat /etc/corosync/corosync.conf
totem {
    version: 2
    secauth: off
    cluster_name: mywebcluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: ha-web1.example.com
        nodeid: 1
    }

    node {
        ring0_addr: ha-web2.example.com
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
}
[root@ha-web1 ~]# 
```


```
[root@ha-web2 ~]# cat /etc/corosync/corosync.conf
totem {
    version: 2
    secauth: off
    cluster_name: mywebcluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: ha-web1.example.com
        nodeid: 1
    }

    node {
        ring0_addr: ha-web2.example.com
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
}
[root@ha-web2 ~]# 
```

**Notes:** 
* The `pcs cluster setup` does not start corosync and pacemaker services on any of the cluster nodes. 
* The default trasport protocol for cluster communication for PCS is **UDP Unicast** or **udpu**. If you choose to use multicast instead, choose a multicast address carefully. See: [http://web.archive.org/web/20101211210054/http://29west.com/docs/THPM/multicast-address-assignment.html](http://web.archive.org/web/20101211210054/http://29west.com/docs/THPM/multicast-address-assignment.html)
* Some guides suggest to create `corosync.conf` by hand, and not use pcs. That is also OK. Eventually those guides do use `pcs` commands to manage the cluster anyway. So making corosync configurations by hand and distributing them using `pcs` is much better then doing by hand. Your choice.


Verify that corosync configuration is also visible through the `pcs cluster corosync` command:

```
[root@ha-web1 ~]# pcs cluster corosync
totem {
    version: 2
    secauth: off
    cluster_name: mywebcluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: ha-web1.example.com
        nodeid: 1
    }

    node {
        ring0_addr: ha-web2.example.com
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
}
[root@ha-web1 ~]# 
```

Since we have not started corosync service yet, you will see so through `pcs status corosync` command:

```
[root@ha-web1 ~]# pcs status corosync
Error: corosync not running
[root@ha-web1 ~]# 
```

-----------

# Start the cluster:

So far we have configured **corosync** through **pcsd**, and we have only started **pcsd** service. It is time to start the cluster. You have to use the same node you used to authenticate to the cluster. i.e. ha-web1 in our case; and use the `pcs cluster start --all` command.

```
[root@ha-web1 ~]# pcs cluster start --all
ha-web2.example.com: Starting Cluster...
ha-web1.example.com: Starting Cluster...
[root@ha-web1 ~]# 
```

Executing the above command on one of the cluster nodes will start corosync and pacemaker services on both/all cluster nodes. This means you should be able to see corosync and pacemaker services startup on both nodes:

```
[root@ha-web1 ~]# systemctl status corosync pacemaker
● corosync.service - Corosync Cluster Engine
   Loaded: loaded (/usr/lib/systemd/system/corosync.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-10-28 13:21:03 CEST; 2min 9s ago
  Process: 2091 ExecStart=/usr/share/corosync/corosync start (code=exited, status=0/SUCCESS)
 Main PID: 2103 (corosync)
    Tasks: 2 (limit: 512)
   CGroup: /system.slice/corosync.service
           └─2103 corosync

Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [VOTEQ ] Waiting for all cluster members. Current votes: 1 expected_votes: 2
Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [QUORUM] Members[1]: 1
Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [MAIN  ] Completed service synchronization, ready to provide service.
Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [TOTEM ] A new membership (192.168.124.51:24) was formed. Members joined: 2
Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [VOTEQ ] Waiting for all cluster members. Current votes: 1 expected_votes: 2
Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [QUORUM] This node is within the primary component and will provide service.
Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [QUORUM] Members[2]: 1 2
Oct 28 13:21:02 ha-web1.example.com corosync[2103]:  [MAIN  ] Completed service synchronization, ready to provide service.
Oct 28 13:21:03 ha-web1.example.com corosync[2091]: Starting Corosync Cluster Engine (corosync): [  OK  ]
Oct 28 13:21:03 ha-web1.example.com systemd[1]: Started Corosync Cluster Engine.

● pacemaker.service - Pacemaker High Availability Cluster Manager
   Loaded: loaded (/usr/lib/systemd/system/pacemaker.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-10-28 13:21:03 CEST; 2min 9s ago
     Docs: man:pacemakerd
           http://clusterlabs.org/doc/en-US/Pacemaker/1.1-pcs/html/Pacemaker_Explained/index.html
 Main PID: 2120 (pacemakerd)
    Tasks: 7 (limit: 512)
   CGroup: /system.slice/pacemaker.service
           ├─2120 /usr/sbin/pacemakerd -f
           ├─2121 /usr/libexec/pacemaker/cib
           ├─2122 /usr/libexec/pacemaker/stonithd
           ├─2123 /usr/libexec/pacemaker/lrmd
           ├─2124 /usr/libexec/pacemaker/attrd
           ├─2125 /usr/libexec/pacemaker/pengine
           └─2126 /usr/libexec/pacemaker/crmd

Oct 28 13:21:04 ha-web1.example.com crmd[2126]:   notice: Connecting to cluster infrastructure: corosync
Oct 28 13:21:04 ha-web1.example.com crmd[2126]:   notice: Quorum acquired
Oct 28 13:21:04 ha-web1.example.com stonith-ng[2122]:   notice: Node ha-web2.example.com state is now member
Oct 28 13:21:04 ha-web1.example.com crmd[2126]:   notice: Node ha-web1.example.com state is now member
Oct 28 13:21:04 ha-web1.example.com crmd[2126]:   notice: The local CRM is operational
Oct 28 13:21:04 ha-web1.example.com crmd[2126]:   notice: State transition S_STARTING -> S_PENDING
Oct 28 13:21:25 ha-web1.example.com crmd[2126]:  warning: Input I_DC_TIMEOUT received in state S_PENDING from crm_timer_popped
Oct 28 13:21:25 ha-web1.example.com crmd[2126]:   notice: State transition S_ELECTION -> S_PENDING
Oct 28 13:21:25 ha-web1.example.com crmd[2126]:   notice: State transition S_PENDING -> S_NOT_DC
[root@ha-web1 ~]# 
```


```
[root@ha-web2 ~]# systemctl status corosync pacemaker
● corosync.service - Corosync Cluster Engine
   Loaded: loaded (/usr/lib/systemd/system/corosync.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-10-28 13:21:03 CEST; 2min 43s ago
  Process: 1825 ExecStart=/usr/share/corosync/corosync start (code=exited, status=0/SUCCESS)
 Main PID: 1837 (corosync)
    Tasks: 2 (limit: 512)
   CGroup: /system.slice/corosync.service
           └─1837 corosync

Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [VOTEQ ] Waiting for all cluster members. Current votes: 1 expected_votes: 2
Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [VOTEQ ] Waiting for all cluster members. Current votes: 1 expected_votes: 2
Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [QUORUM] Members[1]: 2
Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [MAIN  ] Completed service synchronization, ready to provide service.
Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [TOTEM ] A new membership (192.168.124.51:24) was formed. Members joined: 1
Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [QUORUM] This node is within the primary component and will provide service.
Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [QUORUM] Members[2]: 1 2
Oct 28 13:21:02 ha-web2.example.com corosync[1837]:  [MAIN  ] Completed service synchronization, ready to provide service.
Oct 28 13:21:03 ha-web2.example.com corosync[1825]: Starting Corosync Cluster Engine (corosync): [  OK  ]
Oct 28 13:21:03 ha-web2.example.com systemd[1]: Started Corosync Cluster Engine.

● pacemaker.service - Pacemaker High Availability Cluster Manager
   Loaded: loaded (/usr/lib/systemd/system/pacemaker.service; disabled; vendor preset: disabled)
   Active: active (running) since Fri 2016-10-28 13:21:03 CEST; 2min 43s ago
     Docs: man:pacemakerd
           http://clusterlabs.org/doc/en-US/Pacemaker/1.1-pcs/html/Pacemaker_Explained/index.html
 Main PID: 1854 (pacemakerd)
    Tasks: 7 (limit: 512)
   CGroup: /system.slice/pacemaker.service
           ├─1854 /usr/sbin/pacemakerd -f
           ├─1855 /usr/libexec/pacemaker/cib
           ├─1856 /usr/libexec/pacemaker/stonithd
           ├─1857 /usr/libexec/pacemaker/lrmd
           ├─1858 /usr/libexec/pacemaker/attrd
           ├─1859 /usr/libexec/pacemaker/pengine
           └─1860 /usr/libexec/pacemaker/crmd

Oct 28 13:21:25 ha-web2.example.com pengine[1859]:   notice: Configuration ERRORs found during PE processing.  Please run "crm_verify -L" to identify issues.
Oct 28 13:21:25 ha-web2.example.com crmd[1860]:  warning: No reason to expect node 1 to be down
Oct 28 13:21:25 ha-web2.example.com pengine[1859]:    error: Resource start-up disabled since no STONITH resources have been defined
Oct 28 13:21:25 ha-web2.example.com pengine[1859]:    error: Either configure some or disable STONITH with the stonith-enabled option
Oct 28 13:21:25 ha-web2.example.com pengine[1859]:   notice: Delaying fencing operations until there are resources to manage
Oct 28 13:21:25 ha-web2.example.com pengine[1859]:   notice: Calculated transition 1, saving inputs in /var/lib/pacemaker/pengine/pe-input-1.bz2
Oct 28 13:21:25 ha-web2.example.com pengine[1859]:   notice: Configuration ERRORs found during PE processing.  Please run "crm_verify -L" to identify issues.
Oct 28 13:21:25 ha-web2.example.com crmd[1860]:   notice: Transition 1 (Complete=0, Pending=0, Fired=0, Skipped=0, Incomplete=0, Source=/var/lib/pacemaker/pengine/pe-input-1.bz
Oct 28 13:21:25 ha-web2.example.com crmd[1860]:   notice: State transition S_TRANSITION_ENGINE -> S_IDLE

[root@ha-web2 ~]# 
```


**Notice:** the strange errors on node2! (todo).

Using `crm_verify` tells us that there are no resources, which is ok for now.


```
[root@ha-web1 ~]# crm_verify -L -V
   error: unpack_resources:	Resource start-up disabled since no STONITH resources have been defined
   error: unpack_resources:	Either configure some or disable STONITH with the stonith-enabled option
   error: unpack_resources:	NOTE: Clusters with shared data need STONITH to ensure data integrity
Errors found during check: config not valid
[root@ha-web1 ~]# 
```

**Note:** An alternative to using the `pcs cluster start --all` command is to issue either of the below command sequences on each node in the cluster separately. e.g.

``` 
pcs cluster start
``` 
or

```
systemctl start corosync.service

systemctl start pacemaker.service
```

**Note:** In this example, we are not enabling the **corosync** and **pacemaker** services to start at boot. If a cluster node fails or is rebooted, you will need to run `pcs cluster start nodenam` (or `--all`) to start the cluster on it. While you could enable the services to start at boot; requiring a manual start of cluster services gives you the opportunity to do a post-mortem investigation of a node failure before returning it to the cluster. So it is a personal preference to setup **corosync** and **pacemaker** to start at boot or not.


Let us check status of various components again:

```
[root@ha-web1 ~]# pcs status nodes
Pacemaker Nodes:
 Online: ha-web1.example.com ha-web2.example.com
 Standby:
 Maintenance:
 Offline:
Pacemaker Remote Nodes:
 Online:
 Standby:
 Maintenance:
 Offline:

[root@ha-web1 ~]#
```


```
[root@ha-web1 ~]# pcs status resources
NO resources configured
[root@ha-web1 ~]# 
```


```
[root@ha-web1 ~]# pcs status corosync

Membership information
----------------------
    Nodeid      Votes Name
         1          1 ha-web1.example.com (local)
         2          1 ha-web2.example.com
[root@ha-web1 ~]# 
```

You should be able to see that both nodes have joined the cluster.


You can now check the status of corosync cluster using `corosync-cfgtool` , as follows:

```
[root@ha-web1 ~]# corosync-cfgtool -s
Printing ring status.
Local node ID 1
RING ID 0
	id	= 192.168.124.51
	status	= ring 0 active with no faults
[root@ha-web1 ~]# 
```

The same is shown on the other node:

```
[root@ha-web2 ~]# corosync-cfgtool -s
Printing ring status.
Local node ID 2
RING ID 0
	id	= 192.168.124.52
	status	= ring 0 active with no faults
[root@ha-web2 ~]# 
```

It is very important to note few things in the output of `corosync-cfgtool -s` command. These are:
* Our fixed IP of the node (on which this command is issued), is shown and *not* `127.0.0.1` .
* There are no faults reported in the status.

If you see something different, you should stop here and check your configurations from beginning. You may have skipped something important, or misconfigured something.


Next, check cluster membership uing `corosync-cmapctl`:


```
[root@ha-web1 ~]# corosync-cmapctl  | grep members
runtime.totem.pg.mrp.srp.members.1.config_version (u64) = 0
runtime.totem.pg.mrp.srp.members.1.ip (str) = r(0) ip(192.168.124.51) 
runtime.totem.pg.mrp.srp.members.1.join_count (u32) = 1
runtime.totem.pg.mrp.srp.members.1.status (str) = joined
runtime.totem.pg.mrp.srp.members.2.config_version (u64) = 0
runtime.totem.pg.mrp.srp.members.2.ip (str) = r(0) ip(192.168.124.52) 
runtime.totem.pg.mrp.srp.members.2.join_count (u32) = 2
runtime.totem.pg.mrp.srp.members.2.status (str) = joined
[root@ha-web1 ~]#
```


Okay, corosync is working. We get it! Enough verification for corosync. Lets move on with life.


------

# Pacemaker 

At this stage, we have **pcsd** and **corosync**. And, actually we also have pacemaker installed correctly! We just have to verify it! (It got installed by yum, and got configured when we created and started the cluster using the `pcs` command in the previos section.)

```
[root@ha-web1 ~]# ps axf | egrep "corosync|pacemaker" 
 2103 ?        Ssl  113:04 corosync
 2120 ?        Ss     0:00 /usr/sbin/pacemakerd -f
 2121 ?        Ss     0:00  \_ /usr/libexec/pacemaker/cib
 2122 ?        Ss     0:00  \_ /usr/libexec/pacemaker/stonithd
 2123 ?        Ss     0:00  \_ /usr/libexec/pacemaker/lrmd
 2124 ?        Ss     0:00  \_ /usr/libexec/pacemaker/attrd
 2125 ?        Ss     0:00  \_ /usr/libexec/pacemaker/pengine
 2126 ?        Ss     0:01  \_ /usr/libexec/pacemaker/crmd
[root@ha-web1 ~]# 
```

Or

```
[root@ha-web1 ~]# pstree -A $(pidof pacemakerd)
pacemakerd-+-attrd
           |-cib
           |-crmd
           |-lrmd
           |-pengine
           `-stonithd
[root@ha-web1 ~]#
```

We notice that pacemaker master process is running and it's sub processes also running. 

Next check `pcs status` :

```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
WARNING: no stonith devices and stonith-enabled is not false
Stack: corosync
Current DC: ha-web2.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Fri Oct 28 22:17:40 2016		Last change: Fri Oct 28 13:21:25 2016 by hacluster via crmd on ha-web2.example.com

2 nodes and 0 resources configured

Online: [ ha-web1.example.com ha-web2.example.com ]

Full list of resources:


Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

Lets make a note of few things in the output from `pcs status` command:
* There is a warning about "no stonith devices ..." ; which is OK for now.
* Stack is *corosync*.
* Current DC is node2 i.e. ha-web2.
* There are two nodes in the cluster
* There are no resources configured yet
* Both cluster nodes appear online
* Corosync and Pacemaker show as **active/disabled** because they are active , but configured to not boot at system boot.
* pcsd is active and is enabled to start at system boot.

Also check that `journalctl | grep error` does not return any errors on any of the cluster nodes. Such as errors with cluster components **corosync**, **pacemake** or **pcsd**.

We notice that on node `ha-web1`, there are no errors reported in `journalctl`, but on node `ha-web2`, we see errors about STONITH reported by `pengine` . 

```
[root@ha-web2 ~]# journalctl | grep error
. . . 
Oct 28 22:38:24 ha-web2.example.com pengine[1859]:    error: Resource start-up disabled since no STONITH resources have been defined
Oct 28 22:38:24 ha-web2.example.com pengine[1859]:    error: Either configure some or disable STONITH with the stonith-enabled option
Oct 28 22:38:24 ha-web2.example.com pengine[1859]:    error: NOTE: Clusters with shared data need STONITH to ensure data integrity
. . . 
```

We can ignore the STONITH related errors for now, because we wil configure it in the upcoming section.


Before we move on to the next step, it is good to change the validity of the configuration.

```
[root@ha-web1 ~]# crm_verify -L -V
   error: unpack_resources:	Resource start-up disabled since no STONITH resources have been defined
   error: unpack_resources:	Either configure some or disable STONITH with the stonith-enabled option
   error: unpack_resources:	NOTE: Clusters with shared data need STONITH to ensure data integrity
Errors found during check: config not valid
[root@ha-web1 ~]# 
```

```
[root@ha-web2 ~]# crm_verify -L -V
   error: unpack_resources:	Resource start-up disabled since no STONITH resources have been defined
   error: unpack_resources:	Either configure some or disable STONITH with the stonith-enabled option
   error: unpack_resources:	NOTE: Clusters with shared data need STONITH to ensure data integrity
Errors found during check: config not valid
[root@ha-web2 ~]# 
```

The configuration has errors and is invalid. There is no STONITH and the resource startup is disabled. Okay, we get it! Lets do something about it!
 

The brief explanation is:

In order to guarantee the safety of your data, the default for STONITH in Pacemaker is enabled. However, it also knows when no STONITH configuration has been supplied and reports this as a problem (since the cluster would not be able to make progress if a situation requiring node fencing arose). We will disable this feature for now and configure it later. I will discuss STONITH later, and explain why it matters, and in some cases, why not!


## Disable STONITH (temporarily)

To disable STONITH for now, set the `stonith-enabled` cluster option to false:

```
[root@ha-web1 ~]# pcs property set stonith-enabled=false
```

Then, verify again:
```
[root@ha-web1 ~]# crm_verify -L -V
[root@ha-web1 ~]# 
```

Notice, no errors reported this time by `crm_verify`, and no more erros being reported in system logs (`journalctl`).

Lets do `pcs status` again just to know how does it look like:

```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web2.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Sat Oct 29 00:53:56 2016		Last change: Fri Oct 28 23:50:58 2016 by root via cibadmin on ha-web1.example.com

2 nodes and 0 resources configured

Online: [ ha-web1.example.com ha-web2.example.com ]

Full list of resources:


Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

Notice, that PCS does not show the warning about STONITH not being configured. Rest of the output (status) is same as it was before disabling STONITH.





## Location of pacemaker configurations:

At this time you may be wondering *"where are all these configurations stored?"* Well, we already know about corosync that it has it's configuration file `corosync.conf`, stored as `/etc/corosync/corosync.conf` . 

The configuration file used by pacemaker is `cib.xml` and is stored as `/var/lib/pacemaker/cib/cib.xml` .

Please note that these two files must **not** be edited by hand. Instead you must use `pcs` commands to manage the cluster, which creates/adjusts these files accordingly. This files are maintained on both nodes by `pcsd`. (And we know that pcs is an interface for `pcsd`.)


The `pcs cluster cib` shows you the *Cluster Information Base* by actually using contents of the `cib.xml` . 

```
[root@ha-web1 ~]# pcs cluster cib
<cib crm_feature_set="3.0.10" validate-with="pacemaker-2.5" epoch="6" num_updates="0" admin_epoch="0" cib-last-written="Fri Oct 28 23:50:58 2016" update-origin="ha-web1.example.com" update-client="cibadmin" update-user="root" have-quorum="1" dc-uuid="2">
  <configuration>
    <crm_config>
      <cluster_property_set id="cib-bootstrap-options">
        <nvpair id="cib-bootstrap-options-have-watchdog" name="have-watchdog" value="false"/>
        <nvpair id="cib-bootstrap-options-dc-version" name="dc-version" value="1.1.15-1.fc24-e174ec8"/>
        <nvpair id="cib-bootstrap-options-cluster-infrastructure" name="cluster-infrastructure" value="corosync"/>
        <nvpair id="cib-bootstrap-options-cluster-name" name="cluster-name" value="mywebcluster"/>
        <nvpair id="cib-bootstrap-options-stonith-enabled" name="stonith-enabled" value="false"/>
      </cluster_property_set>
    </crm_config>
    <nodes>
      <node id="1" uname="ha-web1.example.com"/>
      <node id="2" uname="ha-web2.example.com"/>
    </nodes>
    <resources/>
    <constraints/>
  </configuration>
  <status>
    <node_state id="2" uname="ha-web2.example.com" in_ccm="true" crmd="online" crm-debug-origin="do_state_transition" join="member" expected="member">
      <transient_attributes id="2">
        <instance_attributes id="status-2">
          <nvpair id="status-2-shutdown" name="shutdown" value="0"/>
        </instance_attributes>
      </transient_attributes>
      <lrm id="2">
        <lrm_resources/>
      </lrm>
    </node_state>
    <node_state id="1" uname="ha-web1.example.com" in_ccm="true" crmd="online" crm-debug-origin="do_state_transition" join="member" expected="member">
      <transient_attributes id="1">
        <instance_attributes id="status-1">
          <nvpair id="status-1-shutdown" name="shutdown" value="0"/>
        </instance_attributes>
      </transient_attributes>
      <lrm id="1">
        <lrm_resources/>
      </lrm>
    </node_state>
  </status>
</cib>
[root@ha-web1 ~]#
```


Notice that our configuration about (disabled) STONITH appears as following in the output above:

```
        <nvpair id="cib-bootstrap-options-stonith-enabled" name="stonith-enabled" value="false"/>
```

In fact, you can use the same command `pcs cluster cib` to save the cluster information as some file, like so:

```
[root@ha-web1 ~]# pcs cluster cib pacemaker-cib-backup.xml
```

Notice the new `.xml` file in our current directory.

```
[root@ha-web1 ~]# ls -lh 
total 8.0K
-rw-------. 1 root root 1.4K Oct 27 13:26 anaconda-ks.cfg
-rw-r--r--  1 root root 2.0K Oct 29 00:13 pacemaker-cib-backup.xml
[root@ha-web1 ~]# 
```


```
[root@ha-web1 ~]# cat pacemaker-cib-backup.xml 
<cib crm_feature_set="3.0.10" validate-with="pacemaker-2.5" epoch="6" num_updates="0" admin_epoch="0" cib-last-written="Fri Oct 28 23:50:58 2016" update-origin="ha-web1.example.com" update-client="cibadmin" update-user="root" have-quorum="1" dc-uuid="2">
  <configuration>
    <crm_config>
      <cluster_property_set id="cib-bootstrap-options">
        <nvpair id="cib-bootstrap-options-have-watchdog" name="have-watchdog" value="false"/>
        <nvpair id="cib-bootstrap-options-dc-version" name="dc-version" value="1.1.15-1.fc24-e174ec8"/>
        <nvpair id="cib-bootstrap-options-cluster-infrastructure" name="cluster-infrastructure" value="corosync"/>
        <nvpair id="cib-bootstrap-options-cluster-name" name="cluster-name" value="mywebcluster"/>
        <nvpair id="cib-bootstrap-options-stonith-enabled" name="stonith-enabled" value="false"/>
      </cluster_property_set>
    </crm_config>
    <nodes>
      <node id="1" uname="ha-web1.example.com"/>
      <node id="2" uname="ha-web2.example.com"/>
    </nodes>
    <resources/>
    <constraints/>
  </configuration>
  <status>
    <node_state id="2" uname="ha-web2.example.com" in_ccm="true" crmd="online" crm-debug-origin="do_state_transition" join="member" expected="member">
      <transient_attributes id="2">
        <instance_attributes id="status-2">
          <nvpair id="status-2-shutdown" name="shutdown" value="0"/>
        </instance_attributes>
      </transient_attributes>
      <lrm id="2">
        <lrm_resources/>
      </lrm>
    </node_state>
    <node_state id="1" uname="ha-web1.example.com" in_ccm="true" crmd="online" crm-debug-origin="do_state_transition" join="member" expected="member">
      <transient_attributes id="1">
        <instance_attributes id="status-1">
          <nvpair id="status-1-shutdown" name="shutdown" value="0"/>
        </instance_attributes>
      </transient_attributes>
      <lrm id="1">
        <lrm_resources/>
      </lrm>
    </node_state>
  </status>
</cib>
[root@ha-web1 ~]# 
```

You can use this file to restore a cluster's configuration by using `cib-push`, like so:

```
pcs cluster cib-push <filename>
```

Or,

```
[root@ha-web1 ~]# pcs cluster cib-push pacemaker-cib-backup.xml
CIB updated
[root@ha-web1 ~]# 
```

----------- 

# Setup our test web service:

(todo: setup a basic index.html for nginx on each node and how that what do we see when we curl each individual IP, and when we curl cluster IP).

Create a custom/unique `index.html` page on each node, so we can verify through the cluster later, that which node is responding through the cluster resource, the cluster IP.


```
[root@ha-web1 ~]# echo "node1 - ha-web1 : nginx - It Works!" > /usr/share/nginx/html/index.html 
```

```
[root@ha-web2 ~]# echo "node2 - ha-web2 : nginx - It Works!" > /usr/share/nginx/html/index.html 
```

```
[root@ha-web1 ~]# systemctl enable nginx; systemctl start nginx
Created symlink from /etc/systemd/system/multi-user.target.wants/nginx.service to /usr/lib/systemd/system/nginx.service.
[root@ha-web1 ~]# 
```

Verify that we are able to access the web service on each node and that we see a web page from each node which uniquely identifies itself. I will use my work computer to `ping` the nodes over ICMP , and access the web services using `curl`:

```
[kamran@kworkhorse ~]$ ping -c1 ha-web1.example.com 
PING ha-web1.example.com (192.168.124.51) 56(84) bytes of data.
64 bytes from ha-web1.example.com (192.168.124.51): icmp_seq=1 ttl=64 time=0.681 ms

--- ha-web1.example.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.681/0.681/0.681/0.000 ms
[kamran@kworkhorse ~]$
```

```
[kamran@kworkhorse ~]$ ping -c1 ha-web2.example.com 
PING ha-web2.example.com (192.168.124.52) 56(84) bytes of data.
64 bytes from ha-web2.example.com (192.168.124.52): icmp_seq=1 ttl=64 time=4.48 ms

--- ha-web2.example.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 4.488/4.488/4.488/0.000 ms
[kamran@kworkhorse ~]$ 
```


Ping the cluster IP and at this time it should fail - which is expected because we have not configured any cluster resource yet:

```
[kamran@kworkhorse ~]$ ping -c1 192.168.124.50
PING 192.168.124.50 (192.168.124.50) 56(84) bytes of data.
From 192.168.124.1 icmp_seq=1 Destination Host Unreachable

--- 192.168.124.50 ping statistics ---
1 packets transmitted, 0 received, +1 errors, 100% packet loss, time 0ms

[kamran@kworkhorse ~]$
```


Lets access each node's web service:

```
[kamran@kworkhorse ~]$ curl ha-web1.example.com
node1 - ha-web1 : nginx - It Works!
[kamran@kworkhorse ~]$ 
```

```
[kamran@kworkhorse ~]$ curl ha-web2.example.com
node2 - ha-web2 : nginx - It Works!
[kamran@kworkhorse ~]$ 
```

As you can see we get a unique page from each web server. Lets see if we can access the web service over the cluster IP:

```
[kamran@kworkhorse ~]$ curl 192.168.124.50
curl: (7) Failed to connect to 192.168.124.50 port 80: No route to host
[kamran@kworkhorse ~]$ 
```

Great! We are almost done!


----------
# Add a cluster resource

Finally it is time to use this cluster to setup some cluster resources ! 

The objective of our excercise today is to setup a VIP (Virtual IP) `192.168.124.50` as a cluster resource, so we can use that IP to access our web service instead of accessing each web server separately. It is common sense to use an IP as VIP, which is not being used anywhere on this network. 

Lets create this resource and name this resource WebVIP:

```
pcs resource create WebVIP ocf:heartbeat:IPaddr2 \
  ip=192.168.124.50 cidr_netmask=32 op monitor interval=30s
```

Or:

```
[root@ha-web1 ~]# pcs resource create WebVIP ocf:heartbeat:IPaddr2 \
>   ip=192.168.124.50 cidr_netmask=32 op monitor interval=30s
[root@ha-web1 ~]#
```

If we check `pcs status`, we would see our resource:

```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web2.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Sat Oct 29 01:01:46 2016		Last change: Sat Oct 29 01:01:40 2016 by root via cibadmin on ha-web1.example.com

2 nodes and 1 resource configured

Online: [ ha-web1.example.com ha-web2.example.com ]

Full list of resources:

 WebVIP	(ocf::heartbeat:IPaddr2):	Started ha-web1.example.com

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

Notice our resource is started on node1, i.e. `ha-web1.example.com` 


If we check the network interface for IP addresses on both nodes, we would notice that the cluster IP (WebVIP), is assigned to network interface on node1 i.e. ha-web1 . 

```
[root@ha-web1 ~]# ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:56:73:ff brd ff:ff:ff:ff:ff:ff
    inet 192.168.124.51/24 brd 192.168.124.255 scope global ens3
       valid_lft forever preferred_lft forever
    inet 192.168.124.50/32 brd 192.168.124.255 scope global ens3
       valid_lft forever preferred_lft forever
[root@ha-web1 ~]# 
```

Notice that the cluster IP is not on node2. i.e. ha-web2 .

```
[root@ha-web2 ~]# ip addr show
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:61:be:64 brd ff:ff:ff:ff:ff:ff
    inet 192.168.124.52/24 brd 192.168.124.255 scope global ens3
       valid_lft forever preferred_lft forever
[root@ha-web2 ~]# 
```


## Verification:

Now we have cluster IP resource on running on the cluster, and is visible on one of the nodes, lets see if we can `ping` it and can access the web service through `curl`:

```
[kamran@kworkhorse ~]$ ping -c1 192.168.124.50
PING 192.168.124.50 (192.168.124.50) 56(84) bytes of data.
64 bytes from 192.168.124.50: icmp_seq=1 ttl=64 time=0.118 ms

--- 192.168.124.50 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.118/0.118/0.118/0.000 ms
[kamran@kworkhorse ~]$
```

Good! The cluster IP `192.168.124.50` is accessible on ICMP! Lets see if we can curl it:

```
[kamran@kworkhorse ~]$ curl 192.168.124.50
node1 - ha-web1 : nginx - It Works!
[kamran@kworkhorse ~]$
```

Also, (since we have a DNS name against the cluster IP):

```
[kamran@kworkhorse ~]$ curl ha-web.example.com
node1 - ha-web1 : nginx - It Works!
[kamran@kworkhorse ~]$ 
```

Super! The web service on node1 is responding against the cluster IP! Our cluster is now alive! Its ALIIIIIIIIIIIIVE!



------------

# Test failover:

So, someone shouted "not so fast!", and I stopped - to test fail-over.

We know (quite evidently) that the cluster IP `192.168.124.50` is on node 1 right now. Lets see if it floats to node2 if node1 fails:

I will pull the power plug of my virtual machine node1 .i.e. ha-web1, using the hypervisor's command.

First, list of running VMs:
```
[root@kworkhorse ~]# virsh list
 Id    Name                           State
----------------------------------------------------
 17    ha-web2                        running
 18    ha-web1                        running
```

Destroy node1:
```
[root@kworkhorse ~]# virsh destroy ha-web1
Domain ha-web1 destroyed
```

Check list of running VMs again - no ha-web1 found!
```
[root@kworkhorse ~]# virsh list
 Id    Name                           State
----------------------------------------------------
 17    ha-web2                        running

[root@kworkhorse ~]# 
```

Lets ping the cluster IP again:

```
[kamran@kworkhorse ~]$ ping -c1 192.168.124.50
PING 192.168.124.50 (192.168.124.50) 56(84) bytes of data.
64 bytes from 192.168.124.50: icmp_seq=1 ttl=64 time=0.123 ms

--- 192.168.124.50 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.123/0.123/0.123/0.000 ms
[kamran@kworkhorse ~]$ 
```

`ping` works!

```
[kamran@kworkhorse ~]$ curl ha-web.example.com
node2 - ha-web2 : nginx - It Works!
[kamran@kworkhorse ~]$
```
`curl` works too! Notice that the response is now coming from node2 instead of node1.

Super! Our little HA cluster has survived a node failure and the service is responding!


If you want to check various components of the cluster now, I will show them to you, including logs:


First, pcs status:
```
[root@ha-web2 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web2.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Sat Oct 29 01:31:59 2016		Last change: Sat Oct 29 01:01:40 2016 by root via cibadmin on ha-web1.example.com

2 nodes and 1 resource configured

Online: [ ha-web2.example.com ]
OFFLINE: [ ha-web1.example.com ]

Full list of resources:

 WebVIP	(ocf::heartbeat:IPaddr2):	Started ha-web2.example.com

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
[root@ha-web2 ~]# 
```

Then, corosync status:
```
[root@ha-web2 ~]# pcs status corosync

Membership information
----------------------
    Nodeid      Votes Name
         2          1 ha-web2.example.com (local)
[root@ha-web2 ~]# 
```

Then, System logs:
```
[root@ha-web2 ~]# journalctl -f
. . .
Oct 29 01:30:35 ha-web2.example.com corosync[1837]:  [MAIN  ] Corosync main process was not scheduled for 7634.6885 ms (threshold is 800.0000 ms). Consider token timeout increase.
Oct 29 01:30:35 ha-web2.example.com corosync[1837]:  [TOTEM ] A processor failed, forming new configuration.
Oct 29 01:30:35 ha-web2.example.com corosync[1837]:  [TOTEM ] A new membership (192.168.124.52:60) was formed. Members
Oct 29 01:30:35 ha-web2.example.com corosync[1837]:  [QUORUM] Members[1]: 2
Oct 29 01:30:35 ha-web2.example.com corosync[1837]:  [MAIN  ] Completed service synchronization, ready to provide service.
. . .
```

Now, just for completeness sake (or fun), lets start node1 again, and see the cluster status.

```
[root@kworkhorse ~]# virsh start ha-web1
Domain ha-web1 started

[root@kworkhorse ~]# 
```

Then I connect to node1 (ha-web1) and check various cluster components:

```
[root@ha-web1 ~]# pcs status
Error: cluster is not currently running on this node
[root@ha-web1 ~]# 
```

What! Well, this is expected. You see we have pcsd service running on this node:

```
[root@ha-web1 ~]# systemctl status pcsd
● pcsd.service - PCS GUI and remote configuration interface
   Loaded: loaded (/usr/lib/systemd/system/pcsd.service; enabled; vendor preset: disabled)
   Active: active (running) since Sat 2016-10-29 01:36:31 CEST; 1min 21s ago
 Main PID: 542 (ruby-mri)
    Tasks: 6 (limit: 512)
   CGroup: /system.slice/pcsd.service
           └─542 /usr/bin/ruby-mri /usr/lib/pcsd/pcsd > /dev/null &

Oct 29 01:36:30 ha-web1.example.com systemd[1]: Starting PCS GUI and remote configuration interface...
Oct 29 01:36:31 ha-web1.example.com systemd[1]: Started PCS GUI and remote configuration interface.
[root@ha-web1 ~]# 
```

But we intentionally configured corosync and pacemaker to **not** start at system boot. This is what is happening. So the cluster is in degrated mode. We can bring up the cluster services on this node - manually. Like so:

```
[root@ha-web1 ~]# pcs cluster start
Starting Cluster...
[root@ha-web1 ~]#
```


Now check cluster status again. It should be up:
```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web2.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Sat Oct 29 01:42:06 2016		Last change: Sat Oct 29 01:01:40 2016 by root via cibadmin on ha-web1.example.com

2 nodes and 1 resource configured

Online: [ ha-web1.example.com ha-web2.example.com ]

Full list of resources:

 WebVIP	(ocf::heartbeat:IPaddr2):	Started ha-web2.example.com

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

Corosync also sees both nodes:

```
[root@ha-web1 ~]# pcs status corosync

Membership information
----------------------
    Nodeid      Votes Name
         1          1 ha-web1.example.com (local)
         2          1 ha-web2.example.com
[root@ha-web1 ~]# 
```

```
[kamran@kworkhorse ~]$ curl ha-web.example.com
node2 - ha-web2 : nginx - It Works!
[kamran@kworkhorse ~]$ 
```

From the above verification, we see that the cluster resource (cluster IP - WebVIP) , which moved to node2 after node1's failure, continue to run on node2 even node1 has re-joined the cluster, which is OK.


Hurray! We did it! Everything works as expected!

---------

# Add a node to HA-with-Pacemaker-Corosync setup

If the nodes are VM, then clone the node. Make adjustments in the following. If not a VM, setp a node from scratch using the steps described above (in the other tutorial):

* /etc/hostname
* /etc/sysconfig/network-scripts/ifcfg-ens3 (change IPADDR, HWADDR and UUID)
* /etc/hosts *(on all nodes)* to add this new node

```
$ cat /etc/hosts

127.0.0.1	localhost.localdomain	localhost
192.168.124.51  ha-web1.example.com     ha-web1
192.168.124.52  ha-web2.example.com     ha-web2
192.168.124.53  ha-web3.example.com     ha-web3
192.168.124.50  ha-web.example.com      ha-web
```


Remove cluster configurations:

```
rm -f /etc/corosync/corosync.conf

rm -f /var/lib/pacemaker/cib/cib.xml
```

Stop corosync and pacemaker services until they are configured properly.


Reboot the new node:

```
 # reboot
```

Since it is a clone, pcsd service would already be running. Verify:

```
[root@ha-web3 ~]# systemctl status pcsd --no-pager
● pcsd.service - PCS GUI and remote configuration interface
   Loaded: loaded (/usr/lib/systemd/system/pcsd.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-11-03 10:06:27 CET; 3h 45min ago
 Main PID: 523 (ruby-mri)
    Tasks: 4 (limit: 512)
   CGroup: /system.slice/pcsd.service
           └─523 /usr/bin/ruby-mri /usr/lib/pcsd/pcsd > /dev/null &

Nov 03 10:06:26 ha-web3.example.com systemd[1]: Starting PCS GUI and remote configuration interface...
Nov 03 10:06:27 ha-web3.example.com systemd[1]: Started PCS GUI and remote configuration interface.
[root@ha-web3 ~]#
```

Also:

```
[root@ha-web1 ~]#  pcs cluster pcsd-status
  ha-web1.example.com: Online
  ha-web2.example.com: Online
[root@ha-web1 ~]# 
``` 


If corosync and pacemaker were configured to *not* start on boot time, then the cluster will be in the stopped state. (IF you rebooted all nodes - that is).

```
[root@ha-web1 ~]#  pcs cluster status
Error: cluster is not currently running on this node
[root@ha-web1 ~]# 
```


Authorize the new node to the cluster, using node1:

```
[root@ha-web1 ~]# pcs cluster auth ha-web3.example.com 
Username: hacluster
Password: 
ha-web3.example.com: Authorized
[root@ha-web1 ~]# 
```


Now add the node to corosync cluster:
```
[root@ha-web1 ~]#  pcs cluster node add ha-web3.example.com
Disabling SBD service...
ha-web3.example.com: sbd disabled
ha-web1.example.com: Corosync updated
ha-web2.example.com: Corosync updated
Setting up corosync...
ha-web3.example.com: Succeeded
Synchronizing pcsd certificates on nodes ha-web3.example.com...
ha-web3.example.com: Success

Restarting pcsd on the nodes in order to reload the certificates...
ha-web3.example.com: Success
[root@ha-web1 ~]#
```

The above command adds the new node to corosync.conf and also replicates/syncs it across all nodes on the cluster. You should be able to see the corosync configuration on node ha-web3:

```
[root@ha-web3 ~]# cat /etc/corosync/corosync.conf
totem {
    version: 2
    secauth: off
    cluster_name: mywebcluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: ha-web1.example.com
        nodeid: 1
    }

    node {
        ring0_addr: ha-web2.example.com
        nodeid: 2
    }

    node {
        ring0_addr: ha-web3.example.com
        nodeid: 3
    }
}

quorum {
    provider: corosync_votequorum
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
}
[root@ha-web3 ~]# 
```

You should get the same from:

```
[root@ha-web3 ~]# pcs cluster corosync
totem {
    version: 2
    secauth: off
    cluster_name: mywebcluster
    transport: udpu
}

nodelist {
    node {
        ring0_addr: ha-web1.example.com
        nodeid: 1
    }

    node {
        ring0_addr: ha-web2.example.com
        nodeid: 2
    }

    node {
        ring0_addr: ha-web3.example.com
        nodeid: 3
    }
}

quorum {
    provider: corosync_votequorum
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
}
[root@ha-web3 ~]# 
```

There is an interesting differnce here compare to the two node cluster we had until now. Notice that a particular configuration setting is not there ay more in the new corosync configuration. It is in the quorum section:

```
quorum {
    provider: corosync_votequorum
    two_node: 1
}
```

So the `two_node: 1` setting is gone, because obviously this is no more a two-node cluster. Just now we added a third node! 


# Start Corosync

Remember, we already *setup* the cluster when in the early stages of this tutorial. We just added a node to the existing cluster. So we just need to start the cluster now - on all nodes.

```
[root@ha-web1 ~]# pcs cluster start --all
ha-web1.example.com: Starting Cluster...
ha-web2.example.com: Starting Cluster...
ha-web3.example.com: Starting Cluster...
[root@ha-web1 ~]# 
```

Great! Lets check the status of various components:

# Check nodes:

```
[root@ha-web1 ~]# pcs status nodes
Pacemaker Nodes:
 Online: ha-web1.example.com ha-web2.example.com ha-web3.example.com
 Standby:
 Maintenance:
 Offline:
Pacemaker Remote Nodes:
 Online:
 Standby:
 Maintenance:
 Offline:
[root@ha-web1 ~]# 
```



# Check cluster status:
```
[root@ha-web1 ~]# pcs cluster status
Cluster Status:
 Stack: corosync
 Current DC: ha-web1.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
 Last updated: Thu Nov  3 15:00:46 2016		Last change: Thu Nov  3 14:58:10 2016 by hacluster via crmd on ha-web1.example.com
 3 nodes and 1 resource configured

PCSD Status:
  ha-web1.example.com: Online
  ha-web3.example.com: Online
  ha-web2.example.com: Online
[root@ha-web1 ~]# 
```

```
[root@ha-web1 ~]# pcs status corosync

Membership information
----------------------
    Nodeid      Votes Name
         1          1 ha-web1.example.com (local)
         2          1 ha-web2.example.com
         3          1 ha-web3.example.com
[root@ha-web1 ~]# 
```

# Check quorum:
```
[root@ha-web1 ~]# pcs status quorum
Quorum information
------------------
Date:             Thu Nov  3 15:05:06 2016
Quorum provider:  corosync_votequorum
Nodes:            3
Node ID:          1
Ring ID:          1/132
Quorate:          Yes

Votequorum information
----------------------
Expected votes:   3
Highest expected: 3
Total votes:      3
Quorum:           2  
Flags:            Quorate 

Membership information
----------------------
    Nodeid      Votes    Qdevice Name
         1          1         NR ha-web1.example.com (local)
         2          1         NR ha-web2.example.com
         3          1         NR ha-web3.example.com

[root@ha-web1 ~]# 
```

# Check if pacemaker is active:

```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web1.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Thu Nov  3 15:06:44 2016		Last change: Thu Nov  3 14:58:10 2016 by hacluster via crmd on ha-web1.example.com

3 nodes and 1 resource configured

Online: [ ha-web1.example.com ha-web2.example.com ha-web3.example.com ]

Full list of resources:

 WebVIP	(ocf::heartbeat:IPaddr2):	Started ha-web1.example.com

Daemon Status:
  corosync: active/disabled
  pacemaker: active/disabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

Notice that Daemon status says `pacemaker: active/disabled` , which means that pacemaker is running, but is not configured to start up at boot time.

Also notice that DC (*Designated Co-ordinator*) is `ha-web1` right now.



## Check corosync and pacemaker services on all nodes:

These two should be **up** on all nodes:

```
[kamran@kworkhorse ~]$ for node in ha-web1 ha-web2 ha-web3; do echo $node; ssh root@${node} systemctl status  corosync| egrep  -w "Loaded:|Active:"; done
ha-web1
   Loaded: loaded (/usr/lib/systemd/system/corosync.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-11-03 14:58:08 CET; 14min ago
ha-web2
   Loaded: loaded (/usr/lib/systemd/system/corosync.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-11-03 14:58:08 CET; 14min ago
ha-web3
   Loaded: loaded (/usr/lib/systemd/system/corosync.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-11-03 14:58:08 CET; 14min ago
[kamran@kworkhorse ~]$ 
```

```
[kamran@kworkhorse ~]$ for node in ha-web1 ha-web2 ha-web3; do echo $node; ssh root@${node} systemctl status  pacemaker| egrep  -w "Loaded:|Active:"; done
ha-web1
   Loaded: loaded (/usr/lib/systemd/system/pacemaker.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-11-03 14:58:08 CET; 14min ago
ha-web2
   Loaded: loaded (/usr/lib/systemd/system/pacemaker.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-11-03 14:58:08 CET; 14min ago
ha-web3
   Loaded: loaded (/usr/lib/systemd/system/pacemaker.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-11-03 14:58:08 CET; 14min ago
[kamran@kworkhorse ~]$ 
```

## Check which resources are available through cluster:

```
[root@ha-web1 ~]# pcs status resources
 WebVIP	(ocf::heartbeat:IPaddr2):	Started ha-web1.example.com
[root@ha-web1 ~]#
```

Or:

```
[root@ha-web1 ~]# pcs status resources --full
 Resource: WebVIP (class=ocf provider=heartbeat type=IPaddr2)
  Attributes: ip=192.168.124.50 cidr_netmask=32
  Operations: start interval=0s timeout=20s (WebVIP-start-interval-0s)
              stop interval=0s timeout=20s (WebVIP-stop-interval-0s)
              monitor interval=30s (WebVIP-monitor-interval-30s)
[root@ha-web1 ~]# 
```

## Check configuration validity:

```
[root@ha-web1 ~]# crm_verify -L -V
[root@ha-web1 ~]# 
```

No output from this command means the configuration has no errors and is valid.


**Note:** We still don't have STONITH, we disabled it when we configured the two node cluster.



# Setup corosync and pacemaker to start automatically on system boot:

In a data center environment, it is better for nodes to come online and bring up their part of cluster stack instead of waiting for the operator to bring up the cluster by manullay issuing `pcs cluster start --all` . To do that we use pcs to enable these services:

```
[root@ha-web1 ~]# pcs cluster enable --all
ha-web1.example.com: Cluster Enabled
ha-web2.example.com: Cluster Enabled
ha-web3.example.com: Cluster Enabled
[root@ha-web1 ~]# 
```

Now, when we reboot nodes, they will come up/online automatically instead of waiting for someone to bring up the cluster.


# Test of all nodes being rebooted:

```
[root@kworkhorse ~]# virsh list 
 Id    Name                           State
----------------------------------------------------
 1     ha-web3                        running
 2     ha-web1                        running
 3     ha-web2                        running

[root@kworkhorse ~]# 
```

```
[root@kworkhorse ~]# virsh shutdown ha-web1
Domain ha-web1 is being shutdown

[root@kworkhorse ~]# virsh shutdown ha-web2
Domain ha-web2 is being shutdown

[root@kworkhorse ~]# virsh shutdown ha-web3
Domain ha-web3 is being shutdown

[root@kworkhorse ~]#
```

Notice no VMs running now:
```
[root@kworkhorse ~]# virsh list 
 Id    Name                           State
----------------------------------------------------

[root@kworkhorse ~]# 
```

Lets start the VMs and see if they bring up the cluster:
```
[root@kworkhorse ~]# virsh start ha-web1
Domain ha-web1 started

[root@kworkhorse ~]# virsh start ha-web2
Domain ha-web2 started

[root@kworkhorse ~]# virsh start ha-web3
Domain ha-web3 started

[root@kworkhorse ~]# 
```


Lets logon to one node and check the cluster status:

```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web3.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Thu Nov  3 15:37:58 2016		Last change: Thu Nov  3 15:27:54 2016 by hacluster via crmd on ha-web1.example.com

3 nodes and 1 resource configured

Online: [ ha-web1.example.com ha-web2.example.com ha-web3.example.com ]

Full list of resources:

 WebVIP	(ocf::heartbeat:IPaddr2):	Started ha-web1.example.com

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

Hurray! The cluster is online! 

Final test, see if the VIP is available and the services are respoding on the VIP:

```
[kamran@kworkhorse ~]$ ping -c 1 ha-web.example.com
PING ha-web.example.com (192.168.124.50) 56(84) bytes of data.
64 bytes from ha-web.example.com (192.168.124.50): icmp_seq=1 ttl=64 time=0.106 ms

--- ha-web.example.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.106/0.106/0.106/0.000 ms
[kamran@kworkhorse ~]$ 
```
Ping works!


```
[kamran@kworkhorse ~]$ curl ha-web.example.com
node1 - ha-web1 : nginx - It Works!
[kamran@kworkhorse ~]$ 
```
Curl works and gets us the web page through the VIP! 

So, it works!


# Important notes about cluster startup, Quorum and Resource startup:

Note that when you have three node cluster, then the required quorum will be **2/3** . i.e. at least two out of three nodes must be alive, and running the cluster stack. If you shutdown all nodes, and bring up only one, the quorum will **NOT** be complete and the cluster resources **will not** start.

In the example below, I started only one node. Notice it says **`partition WITHOUT quorum`** . And it also says that the resource **WebVIP** is **Stopped**. 
```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web1.example.com (version 1.1.15-1.fc24-e174ec8) - partition WITHOUT quorum
Last updated: Fri Nov  4 11:12:59 2016		Last change: Fri Nov  4 11:11:07 2016 by hacluster via crmd on ha-web1.example.com

3 nodes and 1 resource configured

Online: [ ha-web1.example.com ]
OFFLINE: [ ha-web2.example.com ha-web3.example.com ]

Full list of resources:

 WebVIP	(ocf::heartbeat:IPaddr2):	Stopped

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

As soon as I start on more cluster node, the cluster has a quorum , and the resource is started. See below:

```
[root@kworkhorse ~]# virsh start ha-web2
Domain ha-web2 started

[root@kworkhorse ~]# 
```

```
[root@kworkhorse ~]# virsh list
 Id    Name                           State
----------------------------------------------------
 8     ha-web1                        running
 10    ha-web2                        running

[root@kworkhorse ~]# 
```


Check cluster status now:

```
[root@ha-web1 ~]# pcs status
Cluster name: mywebcluster
Stack: corosync
Current DC: ha-web1.example.com (version 1.1.15-1.fc24-e174ec8) - partition with quorum
Last updated: Fri Nov  4 11:18:37 2016		Last change: Fri Nov  4 11:11:07 2016 by hacluster via crmd on ha-web1.example.com

3 nodes and 1 resource configured

Online: [ ha-web1.example.com ha-web2.example.com ]
OFFLINE: [ ha-web3.example.com ]

Full list of resources:

 WebVIP	(ocf::heartbeat:IPaddr2):	Started ha-web1.example.com

Daemon Status:
  corosync: active/enabled
  pacemaker: active/enabled
  pcsd: active/enabled
[root@ha-web1 ~]# 
```

Notice it says **partition with quorum** , and also the resource **WebVIP** is now **Started** on DC (`ha-web1.example.com`) .

--------

# Adding more Resources/Services for the HA cluster to manage (Grouping and Order)

So far we have a resource *WebVIP* which is managed by our HA cluster. Lets add some purpose for this cluster's existence. Until now we had Apache service running on all cluster nodes at all times. Only that web server responded to our queries, which had the VIP. However, if we want the cluster to start the web service only on the node which has the VIP and keep it stopped on the other nodes, then we do it by grouping the resources together. 

A web service is just used here as an example. Normally a web service is a stateless service, and we do not have a cluster of three nodes with only one web service running on the active/master/leader node. Instead, we normally use such a cluster to serve services which can only be run on active node of a cluster at any given time, especially there is a chance of data corruption, when this service is run on multiple cluster nodes. Think about MySQL DB, NFS, etc. These services need a place on the file system to read write data and running them on multiple nodes without proper protection/setup normally ends up in data corruption. e.g. By default, MySQL needs write access to `/var/lib/mysql` . If mysql is running on one cluster node, and that node fails, mysql will move to the other node, ideally with the VIP. But what about the `/var/lib/mysql` directory it lost on the failed node? It needs a mechanism to have the `/var/lib/mysql` synced across the cluster nodes, and as soon as the active node fails, the service is started on a healthy node, and it finds the same `/var/lib/mysql` on the second node. This block level synchronization between multiple nodes, over the network is done by DRBD. So in MySQL's example we need a VIP, a directory protected by DRBD and MySQL service running together only on the active node, and not on any other node. This calls for some service grouping and some ordering. e.g. First the VIP will move to the healthy node, then DRBD will start, and only when these two are active, then MySQL will start - on the same active node. 


In this section,  I will use a simple web service behind a VIP to show how we can add cluster resources, and do grouping and ordering. We would like to see the VIP to float to a healthy cluster node, when the active node dies, and when that resource is running on the new node, only then to bring up the web service. 

Before we begin, it is important to note (and make sure) that the resources (services) which are to be managed by the HA cluster, should not be set to start on the node/system boot time.






--------

# Future work:
* Setup backup mechanisms to backup cluster configurations
* (Done)Add a third node to increase quorum
* Manage a service resource, such as apache/nginx, which will be started and stopped by the cluster.
* Explain STONITH. Why it is important, and why not - at times.
* (Done) Setup *corosync* and *pacemaker* to startup automatically on both nodes. This way the cluster will be up automatically, instead of manual intervention, even for the first time. 
