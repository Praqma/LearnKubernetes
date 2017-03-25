# Build the Docker images
#(cd images/jira; docker build -t hoeghh/jira:7.4.4 .) &
#(cd images/mysql; docker build -t hoeghh/mysql:5.6 .) &

# Wait for them to be finish
#wait 

# Push our Jira and MySql Docker image to docker hub
#docker push hoeghh/jira:7.4.4
#docker push hoeghh/mysql:5.6

# Deploy to Kubernetes
(cd configmaps;
    kubectl apply -f mysql-configmap.yaml
    kubectl apply -f mysql-configmap-confluence.yaml)
(cd secrets;  
    kubectl apply -f mysql-secret.yaml)
(cd services; 
    kubectl apply -f mysql-service.yaml;
    kubectl apply -f confluence-service.yaml)
(cd ingress;  
    kubectl apply -f confluence-ingress.yaml)
(cd deployments;
    kubectl apply -f mysql-deployment.yaml;
    kubectl apply -f confluence-deployment.yaml)
