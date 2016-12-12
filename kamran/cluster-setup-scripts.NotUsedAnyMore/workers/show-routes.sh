#!/bin/bash
CONTROLLER_VIP=$(grep -v \# /etc/hosts | grep "controller\." | awk '{print $1}')
echo "Controller VIP: $CONTROLLER_VIP"
ssh root@${CONTROLLER_VIP} "kubectl get nodes"

for node in $(grep -v \# /etc/hosts| grep "worker[0-9]"  | awk '{print $2}'); do


  ssh root@${CONTROLLER_VIP} \
    "kubectl describe node ${node}"  \
    | egrep -w "Name:|PodCIDR" | tr '\n' '\t' | awk '{print "Pod (CNI/CIDR) Network ",$4," is reachable via host ",$2 }'
done

echo
echo "---------------------------------------------------------------------------"

echo "Execute the following commands on the Linux gateway/router. OR , on ALL cluster nodes, except worker node."
echo "On worker nodes, you do not delete the exiting route, which is connected through cbr0. You just add the other one."
echo
for node in $(grep -v \# /etc/hosts| grep "worker[0-9]"  | awk '{print $2}'); do

  NODE_IP=$(grep -w $node /etc/hosts | grep -v \# | awk '{print $1}')
  # echo $NODE_IP

  # awk -v is to pass an external variable to awk

  ssh root@${CONTROLLER_VIP} \
    "kubectl describe node ${node}"  \
    | egrep -w "Name:|PodCIDR" | tr '\n' '\t' | awk -v IP=$NODE_IP '{ print "route del -net " , $4, "\n", "route add -net " , $4 , " gw " , IP }'
done
echo


