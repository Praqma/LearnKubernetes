kubectl run my-nginx --image=nginx --replicas=1 --port=80
kubectl expose deployment my-nginx --port=80 --type=NodePort
