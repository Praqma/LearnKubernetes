# A script that get triggered when Pods are killed or started
## If we have an external service that needs to be in sync with what our cluster is serving, we need a method to get notified when changes happens and react on them.

### A small example
This a a poor mans version of an eventlistener. There are examples online written in Go and Java that tabs directly into the api server.
kubectl get has an events function that gives us all the events in the namespace default. We can specify another namespace if we want with --namespace=[namespace-name]. By giving it the --watch flag, we will keep getting events, when they happens in the cluster. Now, we only want new events when we start our script, so using --watch-only=true will give us that.

By using awk on the output, we can react on the output from kubectl and call commands based on that.

Here, we echo out when new containers are started, and when they are killed.

```
kubectl get events --watch-only=true | awk '/Started container/ { system("echo Started container") }
                                            /Killing container/ { system("echo Killed container") }'
```

Run the above in a session. Then, in another session start a deployment with two nginx
```
kubectl run my-nginx --image=nginx --replicas=2 --port=80
``` 
Our first session will notify us that it creates two containers. 

Now find a pod to delete
```
kubectl get pods
```
```
NAME                        READY     STATUS    RESTARTS   AGE
my-nginx-2494149703-69t9h   1/1       Running   0          8m
my-nginx-2494149703-eoj2e   1/1       Running   0          8m
```
Now delete a pod, and see our script triggered twice. Once when the pod is deleted, and once when a new pod is created
```
kubectl delete pod my-nginx-2494149703-69t9h
```

Heres my output from our event listener:
```
Started container
Started container
Killed container
Started container
```
First our deployment created two containers, then we killed one and finaly the deployment re-created a pod.
