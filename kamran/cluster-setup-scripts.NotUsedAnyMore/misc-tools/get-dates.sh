#!/bin/bash
# Henrik's script.
# 

ips=$(egrep -v "\#|^127" /etc/hosts | grep -e "[a-z].*[0-9]\.example.com" | awk '{print $1 }')

echo "Assuming you have your SSH RSA public key added to /root/.ssh/authorized_keys on the target nodes,"
echo "this script obtains system date and time from all cluster nodes." 

for node in $ips; do
  echo "Date and time from node : $node : $(ssh root@$node 'date')"
done

