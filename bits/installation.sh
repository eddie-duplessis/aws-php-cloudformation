#!/bin/bash -xe
apt-get update -y

apt-get install python3-pip \
  git build-essential \
  software-properties-common \
  python3-dev libssl-dev libffi-dev \
  jq unzip curl language-pack-en \
  apache2 mysql-client php7.0-common \
  php7.0-cli php7.0-mysql php7.0-dev \
  php7.0-fpm libpcre3-dev php7.0-gd \
  php7.0-curl php7.0-imap php7.0-json \
  php7.0-xml php7.0-mbstring php-sqlite3 \
  php-apcu php7.0-mysql \
  nfs-common \
  -y

sed -i "s/127.0.0.1 localhost/127.0.0.1 localhost $(hostname)/g" /etc/hosts

cd /tmp

# # Install AWS CLI
# curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
# unzip awscli-bundle.zip
# /usr/bin/python3 awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

# # Install SSM
# curl "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb" -o "amazon-ssm-agent.deb"
# dpkg -i amazon-ssm-agent.deb
# systemctl enable amazon-ssm-agent

# # Install Datadog
# REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
# DD_API_KEY=$(/usr/local/aws ssm get-parameters --names MonitoringDataDogKey --region $REGION | jq  -r '.Parameters[].Value')
# curl -L https://raw.githubusercontent.com/DataDog/dd-agent/master/packaging/datadog-agent/source/install_agent.sh

# Elastic Cache
mkdir -p /usr/lib/php/7.0/modules/
wget -P /tmp/ https://s3.amazonaws.com/aws-refarch/wordpress/latest/bits/AmazonElastiCacheClusterClient-2.0.1-PHP70-64bit.tar.gz
tar -xf '/tmp/AmazonElastiCacheClusterClient-2.0.1-PHP70-64bit.tar.gz'
cp '/tmp/artifact/amazon-elasticache-cluster-client.so' /usr/lib/php/7.0/modules/
if [ ! -f /etc/php/7.0/fpm/conf.d/50-memcached.ini ]; then
    touch /etc/php/7.0/fpm/conf.d/50-memcached.ini
fi
sed -i '3i extension=/usr/lib/php/7.0/modules/amazon-elasticache-cluster-client.so;' /etc/php/7.0/fpm/conf.d/50-memcached.ini
sed -i '3i extension=igbinary.so;' /etc/php/7.0/fpm/conf.d/50-memcached.ini

mkdir -p /var/www/application
# mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 fs-65a34a5c.efs.$REGION.amazonaws.com:/ /var/www/application

echo "fs-63a34a5a.efs.$REGION.amazonaws.com:/ /var/www/application nfs4 nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 0 0" >> /etc/fstab
mount -a -t nfs4

# Enable apache2 proxy
a2enmod proxy
a2enmod proxy_fcgi
a2enmod proxy_balancer
a2enmod proxy_http
a2enmod ssl

# Site Config
if [ ! -f /etc/apache2/sites-enabled/perfect.conf ]; then
   touch /etc/apache2/sites-enabled/perfect.conf
   echo 'ServerName 127.0.0.1:80' >> /etc/apache2/sites-enabled/perfect.conf
   echo 'DocumentRoot /var/www/application/perfect' >> /etc/apache2/sites-enabled/perfect.conf
   echo '<Directory /var/www/application/perfect >' >> /etc/apache2/sites-enabled/perfect.conf
   echo '  Options Indexes FollowSymLinks' >> /etc/apache2/sites-enabled/perfect.conf
   echo '  AllowOverride All' >> /etc/apache2/sites-enabled/perfect.conf
   echo '  Require all granted' >> /etc/apache2/sites-enabled/perfect.conf
   echo '</Directory>' >> /etc/apache2/sites-enabled/perfect.conf
   echo 'ProxyPassMatch ^/(.*\.php(/.*)?)$ "unix:/run/php/php7.0-fpm.sock|fcgi://localhost/var/www/application/perfect"' >> /etc/apache2/sites-enabled/loyalwatches.conf
fi

# create hidden opcache directory locally & change owner to apache
if [ ! -d /var/www/.opcache ]; then
    mkdir -p /var/www/.opcache
fi
# enable opcache in /etc/php-7.0.d/10-opcache.ini
sed -i 's/;opcache.file_cache=.*/opcache.file_cache=\/var\/www\/.opcache/' /etc/php/7.0/fpm/conf.d/10-opcache.ini
sed -i 's/opcache.memory_consumption=.*/opcache.memory_consumption=512/' /etc/php/7.0/fpm/conf.d/10-opcache.ini
# download opcache-instance.php to verify opcache status
if [ ! -f /var/www/application/perfect/opcache-instanceid.php ]; then
    wget -P /var/www/application/perfect/ https://s3.amazonaws.com/aws-refarch/wordpress/latest/bits/opcache-instanceid.php
fi


