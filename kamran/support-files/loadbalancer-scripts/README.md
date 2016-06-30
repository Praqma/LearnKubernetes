# The Load Balancer script: 
The external load balancer is a script, run on the LB machine, through a cron job. It constantly monitors kubernetes master over SSH (not through the web api interface). It uses a sqlite DB on the LB to check which services must be created and which should be updated or deleted. It also creates a corresponding haproxy.conf file for each service. 

## Create the SQLite DB on LB:

```
[root@loadbalancer ~]# sqlite3 /opt/LoadBalancer.sqlite.db
SQLite version 3.7.17 2013-05-20 00:56:22
Enter ".help" for instructions
Enter SQL statements terminated with a ";"
sqlite>
```

And, create a table in that DB:
```
sqlite> CREATE TABLE ServiceToEndPointsMapping (ServiceName varchar(50), NameSpace varchar(50), ClusterIP varchar (15), ExternalIP varchar(15), Ports varchar(50), EndPoints varchar(300) );
sqlite> .exit
```
**Note:** When you exit sqlite using `.exit` , then your changes are saved to persistent storage, which is the file(name) you provided when starting sqlite. 

Some notes about this structure:
* The table structure is created based on the outputs of `kubectl get services`and `kubectl describe service <servicename>`commands, as shown below:
```
[vagrant@kubernetes-master ~]$ kubectl get services
NAME         CLUSTER-IP      EXTERNAL-IP       PORT(S)   AGE
kubernetes   10.247.0.1      <none>            443/TCP   9d
nginx        10.247.78.179   192.168.121.201   80/TCP    6d

[vagrant@kubernetes-master ~]$ kubectl describe service nginx
Name:                   nginx
Namespace:              default
Labels:                 run=nginx
Selector:               run=nginx
Type:                   ClusterIP
IP:                     10.247.78.179
Port:                   <unset> 80/TCP
Endpoints:              10.246.82.2:80,10.246.82.6:80
Session Affinity:       None
No events.

[vagrant@kubernetes-master ~]$
```
* ServiceName can be upto 50 characters.
* NameSpace is the name of a namespace where a servie is defined. The script will first generate a list of all services using `kubectl get services --all-namespaces=true` command. Normally the user defined services would be in the namespace named "default".
* Cluster IP can be only one IP, with a max width of 15 characters.
* External IP can be only one IP, with a max width of 15 characters.
* Ports can have a value in the form of portnumber/protocol. Normally this would have one entry with a maximum value of 65535/TCP. Since there may be multiple ports mapped to a service, such as a web server having both 80/TCP and 443/TCP pointing to it, this is set as 50 characters. The LB script will parse this and will generate appropriate haproxy conf files.
* EndPoints  can be a list of comma separated IP addresses (of the backend pods). This is not very scalable in the beginning. e,g, This can currently support few (<15) IP addresses as we have to accomodate a commma and port number associated with each EndPoint IP address. Later, I will move EndPoint IPs to a separate table and join that table with the main table, using a foreign key. [TO DO/ todo ] 



Verify that the table exists even when you exited the sqlite shell:
```
[root@loadbalancer ~]# sqlite3 /opt/LoadBalancer.sqlite.db
SQLite version 3.7.17 2013-05-20 00:56:22
Enter ".help" for instructions
Enter SQL statements terminated with a ";"
sqlite> .tables
ServiceToEndPointsMapping
sqlite> 
```

You can view the table definition (similar to desc in mysql) by using ".schema <tablename>" or "PRAGMA table_info(<tablename>)":

```
sqlite> .tables
ServiceToEndPointsMapping

sqlite> .schema ServiceToEndPointsMapping
CREATE TABLE ServiceToEndPointsMapping (ServiceName varchar(50), NameSpace varchar(50), ClusterIP varchar (15), ExternalIP varchar(15), Ports varchar(50), Endpoints varchar(300) );

sqlite> PRAGMA table_info(ServiceToEndPointsMapping);
0|ServiceName|varchar(50)|0||0
1|NameSpace|varchar(50)|0||0
2|ClusterIP|varchar (15)|0||0
3|ExternalIP|varchar(15)|0||0
4|Ports|varchar(50)|0||0
5|Endpoints|varchar(300)|0||0
sqlite>
``` 

## Populate the table with sample record:
We do it manually right now. Later, the script will do all of this automatically.

```
sqlite> insert into servicetoendpointsmapping values('nginx','default','10.247.78.179','192.168.121.201','80/TCP','10.246.82.2:80,10.246.82.6:80');
```

View the record:
```
sqlite> select * from servicetoendpointsmapping;
nginx|default|10.247.78.179|192.168.121.201|80/TCP|10.246.82.2:80,10.246.82.6:80
sqlite> 
```
Note: You can turn the column headings on by using `.headers on`:
```
sqlite> .headers on
sqlite> select * from servicetoendpointsmapping;
ServiceName|NameSpace|ClusterIP|ExternalIP|Ports|Endpoints
nginx|default|10.247.78.179|192.168.121.201|80/TCP|10.246.82.2:80,10.246.82.6:80
sqlite> 
```


# Creating HAproxy files from the newly created database:

We use two standard files for all the global and default options. 
* haproxy-global-default.cfg and container only the global and default options.
* haproxy-service-template.cfg

Actually, we do not need to have a service template file, as it is very small, and we can create it from the script. (Evaluate/To Do/TODO)




# Future work:
* The script should log it's working to a log file, such as: /var/log/loadbalancer.log
* The script should boot up at system boot time and setup additional network interfaces and haproxy.
* Haproxy service should load **after** the loadbalancer service starts.
