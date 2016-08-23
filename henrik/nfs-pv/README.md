# Kubernetes NFS share as Persistant Volume
## Here we will create a persistant volume in our Kubernetes cluster that mounts a NFS share from another server. This Persisant volume will server our pods with persistant data storrage via persistant volume claims.

### Get a NFS share up and running
See the getting-nfs-running.md for help on getting a test NFS share up and running for this example to work.

### First, lets contain our project to a namespace called production
```
kubectl create namespace production
```

View namespaces in the cluster to see if it was created
```
kubectl get namespaces --show-labels
```

### Create the Persistant Volume (pv)
Change the ip to the ip of your host service the NFS share.
```
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs
spec:
  capacity:
    storage: 50Mi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 10.245.1.1
    path: /opt/nfsshare
```
```
kubectl create -f yaml/nfs-pv.yaml --namespace=production
```

To see information about this persistant volume, run
```
kubectl describe pv nfs --namespace=production
```

### Create a Persistant Volume Claim (pvc)
Now we need to claim some of the storage, so we make a persistant volume claim.
```
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nfs
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Mi
```
```
kubectl create -f yaml/nfs-pvc.yaml --namespace=production
```

To see the pvc (persistant volume claim) run
```
kubectl get pvc --namespace=production
```

### Create a Replication Controller (rc) that uses our PV
Now we will start a RC that spins up some nginx pods, service a html file from our NFS share.

```
apiVersion: v1
kind: ReplicationController
metadata:
  name: nfs-web
spec:
  replicas: 1
  selector:
    role: web-frontend
  template:
    metadata:
      labels:
        role: web-frontend
    spec:
      containers:
      - name: web
        image: nginx
        ports:
          - name: web
            containerPort: 80
        volumeMounts:
          - name: nfs
            mountPath: "/usr/share/nginx/html"
      volumes:
        - name: nfs
          persistentVolumeClaim:
            claimName: nfs
```
```
kubectl create -f yaml/nginx-rc.yaml --namespace=production
```

### Testing
So, to see that this works, you can create a portforward to the pods we created.

First we need to find the names of our pods
```
kubectl get pods --namespace=production
NAME            READY     STATUS    RESTARTS   AGE
nfs-web-1f8ds   1/1       Running   0          41m
nfs-web-330sq   1/1       Running   0          39m

```

Then run the following for each pod
```
kubectl port-forward nfs-web-1f8ds 8081:80 --namespace=production &
kubectl port-forward nfs-web-330sq 8082:80 --namespace=production &
```

Now lets see if we can get the result of our NFS index.html file from the webservers.
```
curl localhost:8081
curl localhost:8082
```

### Test editing of our html file.
Now edit the index.html file on your host, and run the two curl commands again. They should service the new content instantly.
