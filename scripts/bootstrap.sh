#!/usr/bin/env bash

cat <<EOF > /etc/yum.repos.d/mongodb-enterprise-7.0.repo
[mongodb-enterprise-7.0]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2023/mongodb-enterprise/7.0/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
EOF

sudo yum install -y cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl net-snmp openldap openssl xz-libs
sudo yum install -y mongodb-mongosh
sudo yum install -y java-21-amazon-corretto