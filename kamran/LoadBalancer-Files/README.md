# Praqma Load Balancer for Kubernetes

To use this load balancer, you need a dedicated (virtual) machine within your kubernetes cluster (infrastructure) network. Then, you copy the following files to your load balander.
* loadbalancer.sh.cidr
* loadbalancer.conf
* loadbalnacer.sh.flannel 

**Note:** If you are using CNI/CIDR networking, then just copy the first two files. If you are using flannel, then copy the bottom two files. 

Put the conf file in /opt/ and adjust it accordingly.

Put the loadbalancer.sh.<yoursetup> file in /usr/local/bin/ and rename it to loadbalancer.sh . 

Run `loadbalancer.sh show` to see the current setup.

Run `loadbalancer.sh create`to setup the load balancer. 

Make sure tha the services in the kubernetes cluster have an external IP address assigned to them. If not, select an IP address from the pool of available IPs, shown when you run loadbalancer.sh in the `show` mode. There is an issue/bug against this and will be fixed soon. [https://github.com/Praqma/LearnKubernetes/issues/5](https://github.com/Praqma/LearnKubernetes/issues/5) 


Have fun!
