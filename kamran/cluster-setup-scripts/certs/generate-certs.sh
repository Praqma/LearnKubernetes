#!/bin/bash
echo
echo "Checking config file ..."
echo

if [ -f ./certs.conf ] ; then
  source ./certs.conf
else
  echo "certs.conf was not found. Will use defaults for country and city."
fi

if [ -z "${COUNTRY}" ]; then
  COUNTRY=NO
else
  # Pick first two characters of the country, and convert to uppercase.
  COUNTRY=$(echo $COUNTRY | cut -c -2 | tr '[a-z]' '[A-Z]')
fi

if [ -z "${CITY}" ]; then
  CITY=Oslo
fi


if [ -z "${STATE}" ]; then
  STATE=${CITY}
fi


if [ ! -f $HOSTSFILE ] ; then
  echo "Hosts file is not found or not readable. There is no point in creating certificates. Exiting ..."
fi


if [ -z "${DOMAINNAME}" ]; then
  echo "Domain name not specified. There is no point in creating certificates. Exiting ..."
  exit 9
fi

################################### 
echo
echo "Adjusting template files ... Generating configs ..."
echo

sed -e s/CITY/${CITY}/g \
    -e s/STATE/${STATE}/g \
    -e s/COUNTRY/${COUNTRY}/g \
  ca-csr.json.template > ca-csr.json



sed -e s/DOMAINNAME/${DOMAINNAME}/g \
  kubernetes-csr.json.header.template > kubernetes-csr.json.header


sed -e s/CITY/${CITY}/g \
    -e s/STATE/${STATE}/g \
    -e s/COUNTRY/${COUNTRY}/g \
  kubernetes-csr.json.footer.template > kubernetes-csr.json.footer




# Filter IPs and add to template.body
# Notice a single output redirector '>' in the command below:
egrep -v "\#|^127" ${HOSTSFILE} | grep ${DOMAINNAME} | awk '{print "    \"" $1 "\"," }' > kubernetes-csr.body


# Filter out hostnames in FQDN form and add to templete.body 
# Notice two output redirectors '>>' in the line below.
egrep -v "\#|^127" ${HOSTSFILE} | grep ${DOMAINNAME} | awk '{print "    \"" $2 "\"," }' >> kubernetes-csr.body

if [ -z "${EXTERNAL_IP}" ] ; then
  echo "External IP was not defined. Skipping ..."
else
  echo "    \"${EXTERNAL_IP}\"," >> kubernetes-csr.body
fi


# Create the kubernetes-csr.json by combining three files
cat kubernetes-csr.json.header kubernetes-csr.body kubernetes-csr.json.footer > kubernetes-csr.json


###############
echo
echo "Downloading necessary software for generating certificates ..."
echo

curl -# -O https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -# -O https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

cp cfssl_linux-amd64 cfssl
cp cfssljson_linux-amd64 cfssljson

chmod +x cfssl* 

# cp cfssl* /usr/local/bin/cfssljson



################
echo
echo "Generate certificates now ..."
echo 

./cfssl gencert -initca ca-csr.json | ./cfssljson -bare ca

./cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kubernetes-csr.json | ./cfssljson -bare kubernetes


################

echo
echo "Verify certificate ..."
echo 

openssl x509 -in kubernetes.pem -text -noout


echo
echo "Done!"
echo 

echo
echo "New certs generated. You can copy the following files to target computers."
echo

ls -1 *.pem

echo

