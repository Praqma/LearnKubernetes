kubectl create -f nginx.yml
kubectl create -f nginx-svc.yml
kubectl create -f nginx-ing.yml
echo "$(minikube ip) nginx-hej.com" | sudo tee -a /etc/hosts

firefox http://nginx-hej.com
