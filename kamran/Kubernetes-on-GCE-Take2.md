# Kubernetes on Google Container Engine 

This document discusses and explores the setup of two web servers running in a GCE. One web server is Nginx and the other is Apache. We want to see how this is setup and how traffic reaches the containers from outside.


# Install necessary software on your dev computer:

Note: In this document, the dev computer is the one named **kworkhorse** .

## Prerequisits: 
Install gcloud and kubectl on local computer, using instructions from this link: [](https://cloud.google.com/container-engine/docs/before-you-begin "https://cloud.google.com/container-engine/docs/before-you-begin") .

Also:
* Enable Billing for your account,
* Enable Container Engine API
* Create authentication keys:
![](GCE-Credentials-1.png "GCE-Credentials-1.png")
![](GCE-Credentials-2.png "GCE-Credentials-2.png")


In case you already have the software installed, it is good idea to update the gcloud components. 
```
[kamran@kworkhorse ~]$  sudo /opt/google-cloud-sdk/bin/gcloud components update 
```

## Create new project in google cloud: 
Create a new project on GCE, using: [](https://console.cloud.google.com/project)

Note: Project cannot be created through gcloud command. Though you can list projects using the gcloud command:

```
[kamran@kworkhorse ~]$ gcloud  projects  list
PROJECT_ID             NAME              PROJECT_NUMBER
learn-kubernetes-1289  Learn-Kubernetes  185358700664
[kamran@kworkhorse ~]$ 


[kamran@kworkhorse ~]$ gcloud  projects  describe  learn-kubernetes-1289 
createTime: '2016-04-22T08:44:46.593Z'
lifecycleState: ACTIVE
name: Learn-Kubernetes
projectId: learn-kubernetes-1289
projectNumber: '185358700664'
[kamran@kworkhorse ~]$ 
``` 


We see that the project ID of the new project is learn-kubernetes-1289 .

Setup the config for gcloud on your dev computer:
```
gcloud config set project learn-kubernetes-1289
gcloud config set compute/zone europe-west1-b
``` 

Notes: 
* Compute Zones are found here: [](https://cloud.google.com/compute/docs/zones#available)
* Machine types are here: [](https://cloud.google.com/compute/docs/machine-types) 
* Container Engine (Kubernetes) (shows cluster and cluster size, container registry): [](https://console.cloud.google.com/kubernetes)
* Compute Engine (shows VM Instances,CPU usage, Disks, Images, Zones, etc): [](https://console.cloud.google.com/compute) 


## View/verify gcloud defaults:
```
[kamran@kworkhorse LearnKubernetes]$ gcloud config list
Your active configuration is: [default]

[compute]
zone = europe-west1-b
[core]
account = kamranazeem@gmail.com
disable_usage_reporting = False
project = learn-kubernetes-1289
[kamran@kworkhorse LearnKubernetes]$
```





