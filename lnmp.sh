#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

# Configure
MYSQL_ROOT_PASSWORD=""
MYSQL_NORMAL_USER="estuser"
MYSQL_NORMAL_USER_PASSWORD=""

# Check if password is defined
if [[ "$MYSQL_ROOT_PASSWORD" == "" ]]; then
    echo "${CFAILURE}Error: MYSQL_ROOT_PASSWORD not define!!${CEND}";
    exit 1;
fi
if [[ "$MYSQL_NORMAL_USER_PASSWORD" == "" ]]; then
    echo "${CFAILURE}Error: MYSQL_NORMAL_USER_PASSWORD not define!!${CEND}";
    exit 1;
fi

# Force Locale

export LC_ALL="en_US.UTF-8"
echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Add www user and group
addgroup www
useradd -g www -d /home/www -c "www data" -m -s /usr/sbin/nologin www

# Update Package List
apt-get update

# Update System Packages
apt-get -y upgrade

# remove apache2
apt-get purge apache2 -y

# Install Some PPAs
apt-get install -y software-properties-common curl

apt-add-repository ppa:nginx/development -y
apt-add-repository ppa:chris-lea/redis-server -y
apt-add-repository ppa:ondrej/php -y

curl --silent --location https://deb.nodesource.com/setup_9.x | bash -

# Update Package Lists
apt-get update

# Install Some Basic Packages
apt-get install -y build-essential dos2unix gcc git libmcrypt4 libpcre3-dev \
make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim libnotify-bin

# Set My Timezone
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# Install PHP Stuffs
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
php7.2-cli php7.2-dev \
php7.2-pgsql php7.2-sqlite3 php7.2-gd \
php7.2-curl php7.2-memcached \
php7.2-imap php7.2-mysql php7.2-mbstring \
php7.2-xml php7.2-zip php7.2-bcmath php7.2-soap \
php7.2-intl php7.2-readline \
php-xdebug php-pear

# Install Composer
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Add Composer Global Bin To Path
printf "\nPATH=\"$(composer config -g home 2>/dev/null)/vendor/bin:\$PATH\"\n" | tee -a ~/.profile

# Set Some PHP CLI Settings
sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/cli/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.2/cli/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.2/cli/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.2/cli/php.ini

# Install Nginx & PHP-FPM
apt-get install -y --allow-downgrades --allow-remove-essential --allow-change-held-packages \
nginx php7.2-fpm

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
service nginx restart

# Setup Some PHP-FPM Options
echo "xdebug.remote_enable = 1" >> /etc/php/7.2/mods-available/xdebug.ini
echo "xdebug.remote_connect_back = 1" >> /etc/php/7.2/mods-available/xdebug.ini
echo "xdebug.remote_port = 9000" >> /etc/php/7.2/mods-available/xdebug.ini
echo "xdebug.max_nesting_level = 512" >> /etc/php/7.2/mods-available/xdebug.ini
echo "opcache.revalidate_freq = 0" >> /etc/php/7.2/mods-available/opcache.ini

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.2/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.2/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.2/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.2/fpm/php.ini
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php/7.2/fpm/php.ini
sed -i "s/post_max_size = .*/post_max_size = 100M/" /etc/php/7.2/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.2/fpm/php.ini

printf "[openssl]\n" | tee -a /etc/php/7.2/fpm/php.ini
printf "openssl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.2/fpm/php.ini

printf "[curl]\n" | tee -a /etc/php/7.2/fpm/php.ini
printf "curl.cainfo = /etc/ssl/certs/ca-certificates.crt\n" | tee -a /etc/php/7.2/fpm/php.ini

# Disable XDebug On The CLI
sudo phpdismod -s cli xdebug

# Setup Some fastcgi_params Options
cat > /etc/nginx/fastcgi_params << EOF
fastcgi_param	QUERY_STRING		\$query_string;
fastcgi_param	REQUEST_METHOD		\$request_method;
fastcgi_param	CONTENT_TYPE		\$content_type;
fastcgi_param	CONTENT_LENGTH		\$content_length;
fastcgi_param	SCRIPT_FILENAME		\$request_filename;
fastcgi_param	SCRIPT_NAME		\$fastcgi_script_name;
fastcgi_param	REQUEST_URI		\$request_uri;
fastcgi_param	DOCUMENT_URI		\$document_uri;
fastcgi_param	DOCUMENT_ROOT		\$document_root;
fastcgi_param	SERVER_PROTOCOL		\$server_protocol;
fastcgi_param	GATEWAY_INTERFACE	CGI/1.1;
fastcgi_param	SERVER_SOFTWARE		nginx/\$nginx_version;
fastcgi_param	REMOTE_ADDR		\$remote_addr;
fastcgi_param	REMOTE_PORT		\$remote_port;
fastcgi_param	SERVER_ADDR		\$server_addr;
fastcgi_param	SERVER_PORT		\$server_port;
fastcgi_param	SERVER_NAME		\$server_name;
fastcgi_param	HTTPS			\$https if_not_empty;
fastcgi_param	REDIRECT_STATUS		200;
EOF

# Set The Nginx & PHP-FPM User
sed -i "s/user www-data;/user www;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

sed -i "s/user = www-data/user = www/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = www/" /etc/php/7.2/fpm/pool.d/www.conf

sed -i "s/listen\.owner.*/listen.owner = www/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = www/" /etc/php/7.2/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php/7.2/fpm/pool.d/www.conf

service nginx restart
service php7.2-fpm restart

# Install Node
apt-get install -y nodejs

# Install SQLite
apt-get install -y sqlite3 libsqlite3-dev

# Install MySQL
debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASSWORD}"
debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASSWORD}"
apt-get install -y mysql-server

# Configure MySQL
echo "default_password_lifetime = 0" >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "innodb_buffer_pool_size = 128M" >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "innodb_log_file_size = 128M" >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "innodb_file_per_table = 1" >> /etc/mysql/mysql.conf.d/mysqld.cnf
echo "innodb_flush_method = O_DIRECT" >> /etc/mysql/mysql.conf.d/mysqld.cnf

mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "CREATE USER '${MYSQL_NORMAL_USER}'@'0.0.0.0' IDENTIFIED BY '${MYSQL_NORMAL_USER_PASSWORD}';"
mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL ON *.* TO '${MYSQL_NORMAL_USER}'@'127.0.0.1' IDENTIFIED BY '${MYSQL_NORMAL_USER_PASSWORD}' WITH GRANT OPTION;"
mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "GRANT ALL ON *.* TO '${MYSQL_NORMAL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_NORMAL_USER_PASSWORD}' WITH GRANT OPTION;"
mysql --user="root" --password="${MYSQL_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;"
service mysql restart

# Install A Few Other Things
apt-get install -y redis-server memcached beanstalkd

# Configure Supervisor
systemctl enable supervisor.service
service supervisor start

# Configure Beanstalkd
sed -i "s/#START=yes/START=yes/" /etc/default/beanstalkd
/etc/init.d/beanstalkd start

# Enable Swap Memory
/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1

clear
echo "--"
echo "--"
echo "It's Done."
echo "Mysql Root Password: ${MYSQL_ROOT_PASSWORD}"
echo "Mysql Normal User: ${MYSQL_NORMAL_USER}"
echo "Mysql Normal User Password: ${MYSQL_NORMAL_USER_PASSWORD}"
echo "--"
echo "--"