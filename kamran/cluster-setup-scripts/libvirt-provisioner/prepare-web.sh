#!/bin/bash
source ../cluster.conf

if [ -z "${ISO_PATH}" ] || [ ! -f "${ISO_PATH}" ]; then
  echo "The ISO_PATH variable is empty of the file name or file path provided is not readable."
  exit 1
fi 

echo "Mounting the provided ISO image to /mnt/cdrom"
sudo mount -o loop  ${ISO_PATH}  /mnt/cdrom


echo "Running an apache docker container to serve /cdrom and /kicstart"
docker run -v /mnt/cdrom:/usr/local/apache2/htdocs/cdrom \
           -v $(pwd)/../kickstart:/usr/local/apache2/htdocs/kickstart \
       -p 80:80 \
       -d httpd:2.4
echo
echo "-----------------------------------------------------------------------------------------"
docker ps
echo


