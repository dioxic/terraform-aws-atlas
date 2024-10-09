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
sudo yum install -y mongodb-mongosh-shared-openssl3 java-22-amazon-corretto java-1.8.0-amazon-corretto.x86_64 git

type -p yum-config-manager >/dev/null || sudo yum install yum-utils
sudo yum-config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
sudo yum install -y gh

cd /home/ec2-user
gh auth login --with-token ${gh_token}
gh repo clone typhon -- -b chase
cd typhon
./gradlew installdist

cat <<EOF >> /home/ec2-user/.bashrc
alias ty="/home/ec2-user/typhon/build/install/cli/bin/typhon"
alias msh="mongosh"
export URI="${uri}"
export GH_TOKEN="${gh_token}"
EOF