# A simple introduction to Helm on Minikube

## [Step 1: Install minikube](https://github.com/kubernetes/minikube)

```
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube && sudo mv minikube /usr/local/bin/
```

Start it. 
```
minikube start
```

## [Step 2: Setup Helm client](https://github.com/kubernetes/helm)

```
wget https://kubernetes-helm.storage.googleapis.com/helm-v2.7.2-linux-amd64.tar.gz && tar -zxvf helm-v2.0.0-linux-amd64.tgz && mv linux-amd64/helm /usr/local/bin/helm
```
Initialize Helm: 
```
helm init
```

This sets up a Tiller server inside the cluster, which is the Helm server side component. 

## Step 3: Run Jenkins
```
helm install --name jenkins stable/jenkins
```
This downloads and installs the jenkinsci/jenkins image by default, as well as a whole bunch of other settings which can be changed to your heart's content. 

Get your service endpoint:
```
kubectl get svc jenkins-jenkins (--namespace default)
```

or run: 

```
minikube service jenkins-jenkins 
```

### Play with Jenkins : Obtaining admin and password
Get your password running: 
```
printf $(kubectl get secret --namespace default jenkins-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
```

Username is 'admin'.

To clean up run: 
```
helm del --purge jenkins
```

## Step 4: Artifactory
```
helm install --name artifactory stable/artifactory
```
For minikube, the nginx config requires a backend running nginx properly. We are going to sidestep that by running: 
```
kubectl expose svc artifactory --name=external-artifactory --type=NodePort 
```

Which we can open the same way as we did Jenkins: 
```
minikube service external-artifactory
```

Similarly to jenkins, there is a lot of configuration options. 

   Default credential for Artifactory:
   user: admin
   password: password

### Artifactory misc: Setting up your own Volumes
While the artifactory deployment natively already creates volumes, you might notice that these are lost when deleting the artifactory deployment. 
[In the template folder on the helm chart](https://github.com/kubernetes/charts/tree/master/stable/artifactory/templates) there is no PersistantVolume, so what happens is that the Helm deployment itself creates and maintains the volumes. This also means they are deleted, when the deployment is removed resulting in a data loss. 

To circumvent this problem, merely link three volumes to the existing Claims suggested by the deployment like [this one for nginx](pv-arti-nginx.yml), [this one for artifactory itself](pv-arti-arti.yml) and [this one for psql](pv-arti-psql.yml). 

All the PVC created by Helm's Artifactory look for a Storage Class called Standard, so we give that: 
```
storageClassName: Standard
``` 

And it links these volumes and they survive past death. 