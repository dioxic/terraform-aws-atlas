#!/usr/bin/env bash

cat <<EOF > /etc/yum.repos.d/mongodb-enterprise-4.4.repo
[mongodb-enterprise-4.4]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2/mongodb-enterprise/4.4/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.4.asc
EOF

sudo yum install -y cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl net-snmp openldap openssl xz-libs
sudo yum install -y mongodb-enterprise