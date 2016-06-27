FROM centos
MAINTAINER Kamran Azeem (kaz@praqma.net)

# Install some tools in a centos container, as busybox does not have enough troubleshooting tools.
RUN yum -y install bind-utils net-tools nmap tcpdump telnet && yum clean all

# Build and Push (to dockerhub) instructions:
# -------------------------------------------
# docker build -t centos-multitool .
# docker tag centos-multitool kamranazeem/centos-multitool
# docker login
# docker push kamranazeem/centos-multitool

# Pull (from dockerhub) and Usage:
# --------------------------------
# docker pull kamranazeem/centos-multitool

# docker run --rm -it kamranazeem/centos-multitool /bin/bash 
