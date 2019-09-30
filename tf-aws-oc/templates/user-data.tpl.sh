#!/bin/bash
set -e

IPADDR="$( ip addr show dev eth0 | grep "inet " | cut -d\  -f6 | cut -d/ -f1 )"
sudo yum -y install php php-mcrypt php-gd php-mysql php-cli httpd mod_ssl unzip mysql-server

curl https://codeload.github.com/opencart/opencart/zip/2.1.0.2 -o opencart.zip
unzip opencart.zip -d /tmp

sudo mkdir /var/www/html${oc_www_path}
sudo mv /tmp/opencart-2.1.0.2/upload/* /var/www/html${oc_www_path}

cd /var/www/html
sudo touch index.html
sudo chgrp -R apache *

cd /var/www/html${oc_www_path}
sudo touch config.php
sudo touch admin/config.php
sudo chmod 0664 config.php
sudo chmod 0664 admin/config.php
sudo chmod 0775 image
sudo chmod 0775 image/cache
sudo chmod 0775 image/catalog
sudo chmod 0775 system/storage/cache
sudo chmod 0775 system/storage/logs
sudo chmod 0775 system/storage/download
sudo chmod 0775 system/storage/upload
sudo chmod 0775 system/storage/modification

# Start service
sudo chkconfig mysqld on
sudo service mysqld start
sudo chkconfig httpd on
sudo service httpd start

# Config mysql
mysqladmin -u root password ${mysql_password}
#mysqladmin -u root -h $IPADDR password ${mysql_password}
mysql -u root -p${mysql_password} -e "CREATE DATABASE ${oc_db_db};"

# Configure opencart
cd /var/www/html${oc_www_path}/install
sudo php cli_install.php install \
 --db_hostname ${oc_db_host} \
 --db_username ${oc_db_user} \
 --db_password ${oc_db_pass} \
 --db_database ${oc_db_db} \
 --db_driver ${oc_db_type} \
 --username ${oc_user} \
 --password ${oc_pass} \
 --email ${oc_email} \
 --http_server http://${oc_www_host}${oc_www_path}/

# Remove opencart install
cd /var/www/html${oc_www_path}
sudo rm -rf install
