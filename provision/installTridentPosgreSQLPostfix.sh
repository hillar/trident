#!/bin/bash
#
# The quick and dirty method of installing Trident
#
#

TRIDENTVER="1.4.5"
PITCHFORKVER="1.9.4"

if [ "$(id -u)" != "0" ]; then
   echo "ERROR - This script must be run as root" 1>&2
   exit 1
fi

echo $(date) >  /vagrant/provision.log

echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4
export DEBIAN_FRONTEND=noninteractive

echo "installing postgresql nginx postfix ntpdate"
apt-get -y install postgresql nginx postfix ntpdate >> /vagrant/provision.log 1>&2
echo "downloading and installing Trident"
cd /vagrant/
[[ -f "trident-cli_${TRIDENTVER}_amd64.deb" ]]    || wget -4 -q https://github.com/tridentli/trident/releases/download/v$TRIDENTVER/trident-cli_${TRIDENTVER}_amd64.deb
[[ -f "trident-server_${TRIDENTVER}_amd64.deb" ]] || wget -4 -q https://github.com/tridentli/trident/releases/download/v$TRIDENTVER/trident-server_${TRIDENTVER}_amd64.deb
[[ -f "pitchfork-data_${PITCHFORKVER}_all.deb" ]] || wget -4 -q https://github.com/tridentli/trident/releases/download/v$TRIDENTVER/pitchfork-data_${PITCHFORKVER}_all.deb
dpkg -i pitchfork-data_${PITCHFORKVER}_all.deb >> /vagrant/provision.log 1>&2
dpkg -i trident-server_${TRIDENTVER}_amd64.deb >> /vagrant/provision.log 1>&2
dpkg -i trident-cli_${TRIDENTVER}_amd64.deb >> /vagrant/provision.log 1>&2

su - postgres -c "/usr/sbin/tsetup setup_db" >> /vagrant/provision.log 1>&2
su - postgres -c "/usr/sbin/tsetup adduser trident trident" >> /vagrant/provision.log 1>&2

#self signed certificate
mkdir /etc/nginx/ssl
cd /etc/nginx/ssl
cat > server.csr.cnf   <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
[dn]
C=NA
ST=NA
L=NA
O=NA
OU=Testing Domain
emailAddress=administrative-address@awesome-existing-domain-blih-blah.com
CN = localhost
EOF
cat > v3.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = localhost
DNS.2 = trident-server
EOF
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -key rootCA.key -sha256 -days 1024 -out rootCA.pem -config <( cat server.csr.cnf )
openssl genrsa -out server.key 2048
openssl req -new -sha256 -out server.csr -key server.key -config <( cat server.csr.cnf )
openssl x509 -req -in server.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server.crt -days 500 -sha256 -extfile v3.ext
openssl req -in server.csr -pubkey -noout | openssl rsa -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64 -out server.pin


cat > /etc/nginx/sites-available/default <<EOF
# The Trident Daemon Upstream
include /etc/trident/nginx/trident-upstream.inc;

# Trident should only be exposed over HTTPS
# The HTTPS (443) server that exposed Trident
server {
  listen 443 ssl;
  listen [::]:443 ssl;

  server_name trident-server;

  ssl_certificate /etc/nginx/ssl/server.crt;
  ssl_certificate_key /etc/nginx/ssl/server.key;
  ssl_prefer_server_ciphers on;

  # And other SSL options, recommended:
  # - ssl_dhparam
  # - ssl_protocols
  # - ssl_ciphers
  # See https://cipherli.st/ for details

  # STS header
  add_header Strict-Transport-Security \"max-age=31536001\";

  # HTTP Key Pinning
  #add_header Public-Key-Pins 'pin-sha256="base64+primary=="; pin-sha256="base64+backup=="; max-age=5184000; includeSubDomains' always;

  access_log /var/log/nginx/trident-access.log;

  # Include the config for making Trident work
  include /etc/trident/nginx/trident-server.inc;
}
EOF
service nginx restart >> /vagrant/provision.log 1>&2

echo 'trident-handler: "|/usr/sbin/trident-wrapper"' >> /etc/aliases

cat > /etc/postfix/virtual <<EOF
example.net                ----------------
mail-handler@example.net   trident-handler
@example.net               trident-handler
EOF

cat >> /etc/postfix/main.cf <<EOF
# trident ..
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
myhostname = trident-server
myorigin = trident-server
mydestination = trident-server, localhost
virtual_maps = hash:/etc/postfix/virtual
EOF

postmap /etc/postfix/virtual >> /vagrant/provision.log 1>&2
newaliases >> /vagrant/provision.log 1>&2
service postfix reload >> /vagrant/provision.log 1>&2

systemctl start trident.service
sleep 1
netstat -ntple
