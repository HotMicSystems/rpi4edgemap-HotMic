#!/bin/sh
#
# This script will create CA and sign a certificate with it.
#
# * CA certificate (myCA_<timestamp>.crt) is copied to the web server document root
#   so the user can download and install it in the web browser.
# * DNS name is equipped as Wi-Fi AP name to /etc/hostapd.conf
# * DNS name is equipped to /etc/dnsmasq.conf and /etc/dnsmasq.hosts
# * DNS name is used as /etc/hostname
# * DNS name is used at /opt/rnslink/rnslink.ini
#   NOTE: ID Number must be modified by hand!
#
# Example run:
#
# ./tls-setup.sh myEdgeCA edgemap8
#

#
# Create CA and sign certificate
#

CA_NAME=$1
DNS_NAME=$2

if [ -z "$CA_NAME" ]
then
  echo "Usage: tls-setup.sh [CA-NAME] [DNS-NAME]"
  exit
else
  echo "CA name: $CA_NAME"
fi

if [ -z "$DNS_NAME" ]
then
  echo "Usage: tls-setup.sh [CA-NAME] [DNS-NAME]"
  exit
else
  echo "DNS: $DNS_NAME"
fi

# Generate a timestamp for unique file names
TIMESTAMP=$(date +"%Y%m%d%H%M%S")

#
# Create CA
#
CA_KEY="myCA_${TIMESTAMP}.key"
CA_CERT="myCA_${TIMESTAMP}.crt"

openssl req -x509 -new -nodes -newkey rsa:2048 -keyout "$CA_KEY" \
  -sha256 -days 365 -out "$CA_CERT" -subj /CN=$CA_NAME

#
# Create CSR
#
CSR_KEY="edgemap_${TIMESTAMP}.key"
CSR_FILE="edgemap_${TIMESTAMP}.csr"
SIGNED_CERT="edgemap_${TIMESTAMP}.crt"

openssl req -newkey rsa:2048 -nodes -keyout "$CSR_KEY" -out "$CSR_FILE" \
  -subj /CN=edgemap -addext subjectAltName=DNS:$DNS_NAME

#
# Sign
#
openssl x509 -req -in "$CSR_FILE" -copy_extensions copy \
  -CA "$CA_CERT" -CAkey "$CA_KEY" -CAcreateserial -out "$SIGNED_CERT" -days 365 -sha256

#
# Copy files in place for web server and gwsocket daemons
#
cp "$CA_CERT" "$SIGNED_CERT" "$CSR_KEY" /etc/apache2/

#
# Copy CA for client download via http://<DNS_NAME>/myCA_<timestamp>.crt
#
cp "$CA_CERT" /usr/htdocs/

#
# Set Wi-Fi AP name
#
sed -i "s/^ssid=.*/ssid=${DNS_NAME}/" /etc/hostapd.conf

#
# Set /etc/dnsmasq.hosts and /etc/hostname
#
echo "10.1.1.1 $DNS_NAME" > /etc/dnsmasq.hosts
echo $DNS_NAME > /etc/hostname

#
# Set /etc/dnsmasq.conf
#
sed -i "s/^local=.*/local=\/${DNS_NAME}\//" /etc/dnsmasq.conf

#
# Set /opt/rnslink/rnslink.ini
#
sed -i "s/^callsign=.*/callsign=${DNS_NAME}/" /opt/rnslink/rnslink.ini

echo " "
echo "Remember to edit /opt/rnslink/rnslink.ini and change node_id manually!"
echo " "

echo " "
echo "Done. Reboot unit."
echo " "

