
# Docker custom image push to docker hub

First, from my laptop computer. Docker -v says 1.11 .


```
[kamran@registry tmp]$ docker pull nginx
Using default tag: latest
latest: Pulling from library/nginx
51f5c6a04d83: Pull complete 
a3ed95caeb02: Pull complete 
51d229e136d0: Pull complete 
bcd41daec8cc: Pull complete 
Digest: sha256:0fe6413f3e30fcc5920bc8fa769280975b10b1c26721de956e1428b9e2f29d04
Status: Downloaded newer image for nginx:latest
[kamran@registry tmp]$ 
```


```
[kamran@registry tmp]$ cat Dockerfile 
FROM nginx:latest
COPY index.html /usr/share/nginx/html/



[kamran@registry tmp]$ cat index.html 
Custom NGINX image to test push to dockerhub.
[kamran@registry tmp]$ 
```

```
[kamran@registry test]$ docker build --rm -t kamranazeem/mynginx  .
Sending build context to Docker daemon 3.072 kB
Step 1 : FROM nginx:latest
 ---> 0d409d33b27e
Step 2 : COPY index.html /usr/share/nginx/html/
 ---> fefe0a98edc7
Removing intermediate container f71413920622
Successfully built fefe0a98edc7
[kamran@registry test]$ 

```


```
[kamran@registry test]$ docker images | grep nginx
[kamran@registry test]$ docker images | grep nginx
kamranazeem/mynginx                        latest              fefe0a98edc7        21 seconds ago      182.7 MB
nginx                                      latest              0d409d33b27e        12 days ago         182.7 MB
[kamran@registry test]$ 
```

```
[kamran@registry test]$ docker login
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username (kamranazeem): 
Password: (mysupersecretpassword)
Login Succeeded
[kamran@registry test]$ 
```

Push to a public repo on Dockerhub:
 
```
[kamran@registry test]$ docker push kamranazeem/mynginx
The push refers to a repository [docker.io/kamranazeem/mynginx]
96376ad6d505: Pushed 
5f70bf18a086: Mounted from library/nginx 
bbf4634aee1a: Mounted from library/nginx 
64d0c8aee4b0: Mounted from library/nginx 
4dcab49015d4: Mounted from library/nginx 
latest: digest: sha256:0e6937b2e0f209677e142645862d1a48671ecb52d16011538f91b23216f979e8 size: 2185
[kamran@registry test]$ 
```

Now we try to push it to a private repo on dockerhub

Login to docker hub (already did in the previous step).

Create a private repo in docker hub (kamranazeem/private) (format: namespace/reponame)

Apparently Docker treates an image as a repository. That means we can have only one image in private repo.


```
[kamran@registry test]$ docker build --rm -t kamranazeem/private:custom-nginx  .
Sending build context to Docker daemon 3.072 kB
Step 1 : FROM nginx:latest
 ---> 0d409d33b27e
Step 2 : COPY index.html /usr/share/nginx/html/
 ---> Using cache
 ---> fefe0a98edc7
Successfully built fefe0a98edc7
[kamran@registry test]$ 
```

Push to private registry:
```
[kamran@registry test]$ docker push kamranazeem/private:custom-nginx 
The push refers to a repository [docker.io/kamranazeem/private]
96376ad6d505: Mounted from kamranazeem/mynginx 
5f70bf18a086: Mounted from kamranazeem/mynginx 
bbf4634aee1a: Mounted from kamranazeem/mynginx 
64d0c8aee4b0: Mounted from kamranazeem/mynginx 
4dcab49015d4: Mounted from kamranazeem/mynginx 
custom-nginx: digest: sha256:0e6937b2e0f209677e142645862d1a48671ecb52d16011538f91b23216f979e8 size: 2185
[kamran@registry test]$ 
```


---- 

# Trying from kubernetes master

Docker -v says 1.9.1

```
-bash-4.3# docker login
Username: kamranazeem
Password: 
Email: kamranazeem@gmail.com
WARNING: login credentials saved in /root/.docker/config.json
Login Succeeded
```

```
-bash-4.3# cat Dockerfile 
FROM busybox
COPY datafile.txt /tmp/

-bash-4.3# cat datafile.txt 
This is to test busybx.
-bash-4.3# 
```

```
-bash-4.3# docker build --rm -t kamranazeem/private:custom-busybox .
Sending build context to Docker daemon 3.072 kB
Step 1 : FROM busybox
 ---> 0d380282e68b
Step 2 : COPY datafile.txt /tmp/
 ---> 06dd6567e62c
Removing intermediate container 3be7e1dd17e2
Successfully built 06dd6567e62c
-bash-4.3# 
```

Looks like a problem below - for no obvious reason!
```
-bash-4.3# docker push kamranazeem/private:custom-busybox
The push refers to a repository [docker.io/kamranazeem/private] (len: 1)
06dd6567e62c: Preparing 
unauthorized: authentication required
-bash-4.3# 
```







