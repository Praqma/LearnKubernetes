#!/usr/bin/env bash
source tools.f

echo " - Running createLoadBalancer"
createLoadBalancer

echo " - Cleaning up old files"
rm -f /etc/httpd/conf.d/*.bl

echo " - Copying files"
mv -f kubernetes.services.conf /etc/httpd/conf.d/
mv -f *.service.bl /etc/httpd/conf.d/

echo " - Restarting httpd"
sudo service httpd reload
