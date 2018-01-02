kubectl create -f traefik-deploy.yml
kubectl create -f traefik-svc.yml
echo "$(minikube ip) traefik-ui.local" | sudo tee -a /etc/hosts

