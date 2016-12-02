#!/bin/bash
echo "Mounting Fedora 24 DVD.iso to /mnt/cdrom"
sudo mount /home/cdimages/Fedora-Server-dvd-x86_64-24-1.2.iso /mnt/cdrom

echo "Running an apache docker container to serve /cdrom and /kicstart"
docker run -v /mnt/cdrom:/usr/local/apache2/htdocs/cdrom \
           -v $(pwd)/../kickstart:/usr/local/apache2/htdocs/kickstart \
       -p 80:80 \
       -d httpd:2.4
sleep 5
docker ps


