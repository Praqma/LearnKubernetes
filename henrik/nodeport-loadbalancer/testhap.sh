source tools.f 
rm -f *.bl
createLoadBalancer haproxy
cat haproxy.conf
