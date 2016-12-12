# Prepare token and certificate
mkdir -p /var/run/secrets/kubernetes.io/serviceaccount
ln -s /var/lib/kubernetes/kubernetes.pem /var/run/secrets/kubernetes.io/serviceaccount/ca.crt 
touch /var/run/secrets/kubernetes.io/serviceaccount/token

# Run traefik
cd traefik_kubernetes/
./traefik_linux-amd64 -c traefik.toml 
