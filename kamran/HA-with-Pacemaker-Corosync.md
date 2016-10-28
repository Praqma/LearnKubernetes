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
192.168.124.52	ha-web1.example.com	ha-web2
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





## CoroSync

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







