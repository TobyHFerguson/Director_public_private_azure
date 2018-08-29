#!/bin/bash

puser=${1:?"No proxy user provided"}

pwd=${2:?"No password for proxy user provided"}

port=${3:?"No proxy user port provided"}

yum -y -q install squid httpd-tools
systemctl enable squid
touch /etc/squid/passwd &&  chown squid:squid /etc/squid/passwd
echo ${pwd:?} |  htpasswd -i /etc/squid/passwd ${puser}
cat > /tmp/squid.conf <<EOF
acl permitted_destinations any-of all

acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 1025-65535  # unregistered ports
acl CONNECT method CONNECT

# Configuration to allow users in password file to access proxy
auth_param basic program /usr/lib64/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic children 5
auth_param basic realm Squid Basic Authentication
auth_param basic credentialsttl 2 hours
acl auth_users proxy_auth REQUIRED

# Allow/Deny
# Deny requests to certain unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Deny access to anyone who is not an authorized user
http_access deny !auth_users

# Only allow access to the permitted destinations
http_access allow permitted_destinations

# And finally deny all other access to this proxy
http_access deny all

# Squid normally listens to port 3128
http_port ${port:?}
EOF
mv -f /tmp/squid.conf /etc/squid/squid.conf
systemctl start squid
