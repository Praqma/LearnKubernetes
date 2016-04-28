Reference: Container Orchestration using CoreOS and Kubernetes (https://youtu.be/tA8XNVPZM2w)

Kubernetes Infrastructure:
CoreOS
Docker
etcd
flannel
Kubernetes Controller
Kubernetes Node
Terraform
Google Compute Engine



Kubernetes needs a dedicated etcd instance for itself, even if there is a etcd cluster in your environment, kubernetes doesn't want to use that.

Kubernetes controller = 3 components (apiserver, scheduler, replication controller)
Node = Kubelet (which talks to docker) , proxy , docker  

Resource limits should be set so scheduler can pack as much as it can on a node. 

Pod is always deployed as an atomic unit on one node, and of-course it gets its own IP.

If there are multiple containers in a pod, e.g, nginx, redis, mysql, etc, then you can connect to those containers on their shell, using the names defined in the replication controller's definition file. 

$ kubectl exec helloworld-v1-xyzabc -c nginx -- uname -a 


In the command above, "uname -a" is the command to be run on a container named nginx in the helloworld-v1-xyzabc pod. 


Antoher example, where the pod has only one container:

$ kubectl exec somepod -- cat /etc/hosts




Check logs of a container:
$ kubectl logs -f helloworld-v1-xyzabc -c nginx 



You should (MUST) schedule/allocate resources using cgroups, etc. You can also introduce health endpoints. (reference Kelsey's presentation "strangloop" Sept 25-26 2015.)


Any pod, when created has a very small "Infrastructure" container in it, and that is the firt container created (implicitly) in a pod. This container just sits there and does nothing. This is the container, which gets an IP from the underlying docker service and asks it to create a network for it. Docker does that dutyfully and then when the next (actual) container is created it asks docker to create it and make it part of the same network as the infrastructure container. The infrastructure container is hidden from view. It consumes no resources and it's task is just to stay alive and hold the IP which it recieved from Docker. This is the IP used by the entire pod. 


It is also possible to restart a single container in a pod and not disturb other containers of that pod.


proxy runs on each node and manages iptables on each node.




