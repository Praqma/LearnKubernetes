* Master: 52.58.169.227 (172.31.4.165)
* Node1:  52.58.141.9   (172.31.4.166)
* Node2:  52.58.112.190 (172.31.4.167)


```
ssh -i Downloads/Kubernetes-Cluster-on-Atomic-Oslo.pem fedora@NodeIP

sudo rpm-ostree upgrade && sudo systemctl reboot
```










```
docker tag pullvoice-tomcat:latest \
  ec2-52-51-123-41.eu-west-1.compute.amazonaws.com:5000/pullvoice-tomcat:latest
```

```
kubectl expose rc nginx --port=80 --target-port=80 --external-ip=52.50.170.242 -l run=nginx
```


Note: Disable ServiceAccount in admission controls.




