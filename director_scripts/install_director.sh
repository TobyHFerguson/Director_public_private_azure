#!/bin/bash

export http_proxy=${1:?"Missing proxy argument"}
[[ "$http_proxy" =~ (.*)://(.*):(.*)@(.*):([0-9][0-9]*) ]] || {
    cat 1>&2 <<-EOF
    http proxy argument incorrectly formatted. Need a proxy like this '(UPPER CASE SHOWS PLACEHOLDERS)'

    PROTOCOL://USER:PASSWORD@FQDN_OR_IP:PORT

    Exiting
EOF
}

# Wait for proxy
until curl -s ${BASH_REMATCH[1]}://${BASH_REMATCH[4]}:${BASH_REMATCH[5]} 1>&2
do
    echo 'Proxy unavailable. Sleeping for 5 seconds'
    sleep 5
done
# Install JDK
yum -y remove --assumeyes *openjdk*
rpm -ivh "https://archive.cloudera.com/director/redhat/7/x86_64/director/2/RPMS/x86_64/oracle-j2sdk1.8-1.8.0+update121-1.x86_64.rpm"

# Install Cloudera Director
cd /etc/yum.repos.d/
curl -L -O https://archive.cloudera.com/director/redhat/7/x86_64/director/cloudera-director.repo
yum -y install cloudera-director-server cloudera-director-client

# Configure director for proxy
sed -i -e "s/# \(lp.proxy.http.scheme:\)/\1${BASH_REMATCH[1]}/" \
    -e "s/# \(lp.proxy.http.username:\)/\1${BASH_REMATCH[2]}/" \
    -e "s/# \(lp.proxy.http.password:\)/\1${BASH_REMATCH[3]}/" \
    -e "s/# \(lp.proxy.http.host:\)/\1${BASH_REMATCH[4]}/" \
    -e "s/# \(lp.proxy.http.port:\)/\1${BASH_REMATCH[5]}/" /etc/cloudera-director-server/application.properties

systemctl restart cloudera-director-server
