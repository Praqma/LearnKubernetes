# Traefik as a loadbalancer (in kubernetes)
First of all, all credit goes to traefik.io for a solid solution.

The next few steps can also be found on https://docs.traefik.io/user-guide/kubernetes/

## Deploy Træfik as an ingress controller
All of the steps assume that you are running a small cluster on minikube, which can be found in googles official repository here: https://github.com/kubernetes/minikube

Run:
```
kubectl create -f traefik-deploy.yml
```

This will create an ingress controller running Træfik.

## Deploy services to support Trækfik UI
Next step is to do the same for the two UI services for Træfik.
```
kubectl create -f traefik-svc.yml
echo "$(minikube ip) traefik-ui.local" | sudo tee -a /etc/hosts
```

These two steps adds the services, as well as the host entry that Træfik depends on to route traffic.

Test it by writing traefik-ui.local in your browser!

## Deploy another service - hello world with Nginx!
The last part is running through the same concept for a "real" service, here Nginx.

```
kubectl create -f nginx-svc.yml
kubectl create -f nginx-ing.yml
echo "$(minikube ip) yournginx.com" | sudo tee -a /etc/hosts
```


Use your own name if you want, but if you copy / pasted the commands then access it on yournginx.com
