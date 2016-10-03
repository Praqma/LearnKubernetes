## NodePort Loadbalancer
# Introduction
This folder contains an example of how to update a Apache webserver to reflect services running in a Kubernetes Cluster by loadbalancing them. It will create a loadbalancer for each exposed service with endpoints.

The file tools.f contains two functions. createLoadBalancer and createServiceLB. 

createServiceLB creates the lines needed for each service. It finds the ip's and port of each node and add them to a BalancerMember for that service. It write this to a file ending with .bal. At the end of each .bal file, we add a ProxyPass and ProxyPassRevers for the service as well.

createLoadBalancer will create the outer VirtualHost part, and then including alle the .bal files in it, when loaded by Apache. It saves this in a file called kubernetes.services.conf.

If kubernetes.services.conf and all the .bal files are copied to eg /etc/httpd/conf.d and apache is reloaded, you will have a funtionel loadbalancer.

# How to use
We have created a run.sh script that shows how you can use the functions. In this example, we have an Apache running on the host machine. We call createLoadBalancer and it creates the files we need. It then copies them to /etc/httpd/conf.d/ and reloads the Apache webserver.

Then, go to localhost/balancer-manager to see your loadbalancer reflect your services in your Kubernetes cluster. As mentioned earlier, only services with endpoints and a nodeport assigned, will be processed.

