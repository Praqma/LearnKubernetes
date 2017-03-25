# Deploy to Kubernetes
(cd configmaps;
    kubectl delete -f mysql-configmap.yaml
    kubectl delete -f mysql-configmap-confluence.yaml)
(cd secrets;
    kubectl delete -f mysql-secret.yaml)
(cd services;
    kubectl delete -f mysql-service.yaml;
    kubectl delete -f confluence-service.yaml)
(cd ingress;
    kubectl delete -f confluence-ingress.yaml)
(cd deployments;
    kubectl delete -f mysql-deployment.yaml;
    kubectl delete -f confluence-deployment.yaml)

