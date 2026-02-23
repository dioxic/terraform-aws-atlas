#!/usr/bin/env bash

cat <<EOF > /etc/yum.repos.d/mongodb-enterprise-8.0.repo
[mongodb-enterprise-8.0]
name=MongoDB Enterprise Repository
baseurl=https://repo.mongodb.com/yum/amazon/2023/mongodb-enterprise/8.0/\$basearch/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-8.0.asc
EOF

sudo yum install -y cyrus-sasl cyrus-sasl-gssapi cyrus-sasl-plain krb5-libs libcurl net-snmp openldap openssl xz-libs
sudo yum install -y mongodb-mongosh-shared-openssl3 java-21-amazon-corretto git

type -p yum-config-manager >/dev/null || sudo yum install yum-utils
sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo yum install -y gh

cd /home/ec2-user
wget https://github.com/dioxic/mgenerate4j/releases/download/v0.0.7/mgenerate.jar
gh auth login --with-token ${gh_token}

cat <<EOF >> /home/ec2-user/.bashrc
alias ty="/home/ec2-user/typhon/build/install/cli/bin/typhon"
alias mgen="java -jar /home/ec2-user/mgenerate.jar"
alias msh="mongosh"
export URI="${uri}"
export STATS_URI="${stats_uri}"
export GH_TOKEN="${gh_token}"
EOF

source /home/ec2-user/.bashrc
gh repo clone typhon -- -b nv
cd typhon
./gradlew installdist
cd /home/ec2-user
chown -R ec2-user: typhon