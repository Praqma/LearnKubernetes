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

**Note:**  Authenticate pcs to pcsd on nodes specified, or on all nodes configured in corosync.conf if no nodes are specified. Authorization tokens are stored in ~/.pcs/tokens ; or /var/lib/pcsd/tokens for root.

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

So far we have configured **pcsd** and **corosync** , and we have only started **pcsd** service. It is time to start the cluster. You have to use the same node you used to authenticate to the cluster. i.e. ha-web1 in our case; and use the `pcs cluster start --all` command.

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

**Notes:**
* An alternative to using the pcs cluster start --all command is to issue either of the below command sequences on each node in the cluster separately. e.g.

``` 
 # pcs cluster start
 Starting Cluster...
``` 
or

```
# systemctl start corosync.service
# systemctl start pacemaker.service
```

* In this example, we are not enabling the **corosync** and **pacemaker** services to start at boot. If a cluster node fails or is rebooted, you will need to run `pcs cluster start nodenam` (or `--all`) to start the cluster on it. While you could enable the services to start at boot; requiring a manual start of cluster services gives you the opportunity to do a post-mortem investigation of a node failure before returning it to the cluster. So it is a personal preference to setup **corosync** and **pacemaker** to start at boot or not.













---------- 




On both nodes, copy the corosync example file as corosync config file.

```
cp /etc/corosync/corosync.conf.example /etc/corosync/corosync.conf 
```

The config file should look like the one shown below. **Make sure** that the bindnetaddr is the same network , which you are connnected to using the network interface of this machine. In my case, my nodes are connected to `192.168.124.0/24` network. You do not need to provide `/24` in the `bindnetaddr` directive in the config file. If you have multiple network interface cards then read the example config file for directions.

```
 # grep -v \# /etc/corosync/corosync.conf

totem {
	version: 2

	crypto_cipher: none
	crypto_hash: none

	interface {
		ringnumber: 0
		bindnetaddr: 192.168.124.0
		mcastaddr: 239.255.1.1
		mcastport: 5405
		ttl: 1
	}
}

logging {
	fileline: off
	to_stderr: no
	to_logfile: yes
	logfile: /var/log/cluster/corosync.log
	to_syslog: yes
	debug: off
	timestamp: on
	logger_subsys {
		subsys: QUORUM
		debug: off
	}
}

quorum {
}
```

Start corosync service on both nodes:

```
service corosync start
```

Verify that the service is running:
```
 # service corosync status

Redirecting to /bin/systemctl status  corosync.service
● corosync.service - Corosync Cluster Engine
   Loaded: loaded (/usr/lib/systemd/system/corosync.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-10-27 15:19:26 CEST; 5min ago
  Process: 1296 ExecStop=/usr/share/corosync/corosync stop (code=exited, status=0/SUCCESS)
  Process: 1311 ExecStart=/usr/share/corosync/corosync start (code=exited, status=0/SUCCESS)
 Main PID: 1324 (corosync)
    Tasks: 2 (limit: 512)
   CGroup: /system.slice/corosync.service
           └─1324 corosync

Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [QB    ] server name: cfg
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync cluster closed process group service v1.01 [2]
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [QB    ] server name: cpg
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync profile loading service [4]
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync cluster quorum service v0.1 [3]
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [QB    ] server name: quorum
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [TOTEM ] A new membership (192.168.124.51:4) was formed. Members joined: 3232267315
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [MAIN  ] Completed service synchronization, ready to provide service.
Oct 27 15:19:26 ha-web1.example.com corosync[1311]: Starting Corosync Cluster Engine (corosync): [  OK  ]
Oct 27 15:19:26 ha-web1.example.com systemd[1]: Started Corosync Cluster Engine.
```


You should have the following in your logs, on each node:

```
 # journalctl -u 
Oct 27 15:19:25 ha-web1.example.com systemd[1]: Starting Corosync Cluster Engine...
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [TOTEM ] Initializing transport (UDP/IP Multicast).
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [TOTEM ] Initializing transmit/receive security (NSS) crypto: none hash: none
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [TOTEM ] The network interface [192.168.124.51] is now up.
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync configuration map access [0]
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [QB    ] server name: cmap
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync configuration service [1]
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [QB    ] server name: cfg
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync cluster closed process group service v1.01 [2]
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [QB    ] server name: cpg
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync profile loading service [4]
Oct 27 15:19:25 ha-web1.example.com corosync[1324]:   [SERV  ] Service engine loaded: corosync cluster quorum service v0.1 [3]
```


On node1, watch the logs, because you want to see if starting corosync service makes the other node join the ring/cluster or not.

```
 # journalctl -xef
. . . 
Oct 27 15:25:37 ha-web1.example.com corosync[1324]:   [TOTEM ] A new membership (192.168.124.51:8) was formed. Members joined: 3232267316
Oct 27 15:25:37 ha-web1.example.com corosync[1324]:   [MAIN  ] Completed service synchronization, ready to provide service.
```

Notice that the two nodes have now formed a cluster (using TOTEM ring). 

You should be able to notice the same when you do `service corosync status` :

```
[root@ha-web2 ~]# service corosync status
Redirecting to /bin/systemctl status  corosync.service
● corosync.service - Corosync Cluster Engine
   Loaded: loaded (/usr/lib/systemd/system/corosync.service; disabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-10-27 15:25:37 CEST; 8min ago
  Process: 1176 ExecStop=/usr/share/corosync/corosync stop (code=exited, status=0/SUCCESS)
  Process: 1191 ExecStart=/usr/share/corosync/corosync start (code=exited, status=0/SUCCESS)
 Main PID: 1205 (corosync)
    Tasks: 2 (limit: 512)
   CGroup: /system.slice/corosync.service
           └─1205 corosync

Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [QB    ] server name: cpg
Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [SERV  ] Service engine loaded: corosync profile loading service [4]
Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [SERV  ] Service engine loaded: corosync cluster quorum service v0.1 [3]
Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [QB    ] server name: quorum
Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [TOTEM ] A new membership (192.168.124.52:4) was formed. Members joined: 3232267316
Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [MAIN  ] Completed service synchronization, ready to provide service.
Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [TOTEM ] A new membership (192.168.124.51:8) was formed. Members joined: 3232267315
Oct 27 15:25:37 ha-web2.example.com corosync[1205]:   [MAIN  ] Completed service synchronization, ready to provide service.
Oct 27 15:25:37 ha-web2.example.com corosync[1191]: Starting Corosync Cluster Engine (corosync): [  OK  ]
Oct 27 15:25:37 ha-web2.example.com systemd[1]: Started Corosync Cluster Engine.
[root@ha-web2 ~]# 
```


## Enable corosync and other two services - on both nodes:

```
[root@ha-web1 ~]# systemctl enable corosync pacemaker pcsd
Created symlink from /etc/systemd/system/multi-user.target.wants/corosync.service to /usr/lib/systemd/system/corosync.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/pacemaker.service to /usr/lib/systemd/system/pacemaker.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/pcsd.service to /usr/lib/systemd/system/pcsd.service.
[root@ha-web1 ~]# 
```

```
[root@ha-web2 ~]# systemctl enable corosync pacemaker pcsd
Created symlink from /etc/systemd/system/multi-user.target.wants/corosync.service to /usr/lib/systemd/system/corosync.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/pacemaker.service to /usr/lib/systemd/system/pacemaker.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/pcsd.service to /usr/lib/systemd/system/pcsd.service.
[root@ha-web2 ~]# 
```

# Start Pacemaker service:

On both nodes:

```
[root@ha-web1 ~]# service pacemaker status
Redirecting to /bin/systemctl status  pacemaker.service
● pacemaker.service - Pacemaker High Availability Cluster Manager
   Loaded: loaded (/usr/lib/systemd/system/pacemaker.service; enabled; vendor preset: disabled)
   Active: active (running) since Thu 2016-10-27 15:37:36 CEST; 2min 27s ago
     Docs: man:pacemakerd
           http://clusterlabs.org/doc/en-US/Pacemaker/1.1-pcs/html/Pacemaker_Explained/index.html
 Main PID: 1408 (pacemakerd)
   CGroup: /system.slice/pacemaker.service
           ├─1408 /usr/sbin/pacemakerd -f
           ├─1409 /usr/libexec/pacemaker/cib
           ├─1410 /usr/libexec/pacemaker/stonithd
           ├─1411 /usr/libexec/pacemaker/lrmd
           ├─1412 /usr/libexec/pacemaker/attrd
           ├─1413 /usr/libexec/pacemaker/pengine
           └─1414 /usr/libexec/pacemaker/crmd

Oct 27 15:37:37 ha-web1.example.com crmd[1414]:    error: Corosync quorum is not configured
Oct 27 15:37:37 ha-web1.example.com cib[1409]:   notice: Defaulting to uname -n for the local corosync node name
Oct 27 15:39:58 ha-web1.example.com pacemakerd[1408]:   notice: Could not obtain a node name for corosync nodeid 3232267316
Oct 27 15:39:58 ha-web1.example.com stonith-ng[1410]:   notice: Could not obtain a node name for corosync nodeid 3232267316
Oct 27 15:39:58 ha-web1.example.com stonith-ng[1410]:   notice: Node (null) state is now member
Oct 27 15:39:58 ha-web1.example.com attrd[1412]:   notice: Could not obtain a node name for corosync nodeid 3232267316
Oct 27 15:39:58 ha-web1.example.com attrd[1412]:   notice: Node (null) state is now member
Oct 27 15:39:58 ha-web1.example.com cib[1409]:   notice: Could not obtain a node name for corosync nodeid 3232267316
Oct 27 15:39:58 ha-web1.example.com cib[1409]:   notice: Node (null) state is now member
Oct 27 15:39:59 ha-web1.example.com crmd[1414]:   notice: Could not obtain a node name for corosync nodeid 3232267316
[root@ha-web1 ~]# 
``` 

**Notice:** The error : `error: Corosync quorum is not configured`







