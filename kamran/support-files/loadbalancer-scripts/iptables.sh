#!/bin/bash

LB_PUBLIC_IP=192.168.121.201

echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A PREROUTING -p tcp -d ${LB_PUBLIC_IP} --dport 80 -j DNAT --to 10.246.92.8:80
iptables -t nat -A POSTROUTING -p tcp -o flannel0 -j MASQUERADE
