#!/bin/bash

set -e
source ./config.ini

if [ ! -d "${DOCUMENT_ROOT}" ]; then
    mkdir -pv $DOCUMENT_ROOT
    sudo chown $USER:www-data $DOCUMENT_ROOT
    sudo chmod -R u=rwX,g=rX,o= $DOCUMENT_ROOT
else
    echo "* Document root directory is alreay exist. Change the directory and try again."
    exit 1
fi

APACHE="apache2"
MYSQL="mysql-server"
# mysql-server will install mysql-server, libmysqlclient18, mysql-common
PHP="php5 php5-dev php5-mysql php5-curl php5-mcrypt php5-gd"
# php5  will install php5, php5-cli, php5-common, php5-json, php5-readline, libapache2-mod-php5

echo mysql-server-5.5 mysql-server/root_password        password ${MYSQL_PASS} | sudo debconf-set-selections
echo mysql-server-5.5 mysql-server/root_password_again  password ${MYSQL_PASS} | sudo debconf-set-selections

if [[ "${INSTALL_XDEBUG}" == true ]]; then
  PHP="$PHP php5-xdebug"
fi
if [[ "${INSTALL_MEMCACHED}" == true ]]; then
  PHP="$PHP memcached php5-memcached"
fi

function install_lamp() {
    sudo apt-get -yq install $APACHE $MYSQL $PHP
}
function restart_web_server() {
    sudo service mysql restart
    sudo service apache2 restart
}
function remove_apache() {
    sudo service apache2 stop
    sudo apt-get -yq purge $APACHE
    sudo apt-get -yq autoremove
}
function remove_mysql() {
    sudo service mysql stop
    sudo apt-get -yq purge $MYSQL
    sudo apt-get -yq autoremove
}
function remove_php() {
    sudo apt-get -yq purge $PHP
    sudo apt-get -yq autoremove
}
function remove_lamp() {
    sudo service apache2 stop
    sudo service mysql stop
    sudo apt-get -yq purge $APACHE $MYSQL $PHP
    sudo apt-get -yq autoremove
}
function configure_lamp() {
    #sudo a2enmod ssl               #enable
    sudo a2enmod rewrite    #enable
    #sudo a2dismod cgi             #disable
    #sudo a2dismod autoindex #disable

    REPLACE=$(echo "${DOCUMENT_ROOT}" | sed 's|/|\\/|g')
    sudo sed -i "s/\/var\/www/$REPLACE/g" /etc/apache2/apache2.conf
    sudo sed -i "s/\/var\/www\/html/$REPLACE/g" /etc/apache2/sites-available/000-default.conf
    echo "ServerName localhost" >> /etc/apache2/apache2.conf

    # ----- Configure Mysql -----
    ##sudo sed -i 's/#log_slow_queries/log_slow_queries/g'          /etc/mysql/my.cnf
    ##sudo sed -i 's/#long_query_time/long_query_time/g'            /etc/mysql/my.cnf

    # ----- Configure PHP -----
    ##sudo sed -i 's/magic_quotes_gpc = On/magic_quotes_gpc = Off/g'          /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
    ##sudo sed -i 's/short_open_tag = On/short_open_tag = Off/g'              /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
    ##sudo sed -i 's/max_execution_time = [0-9]\+/max_execution_time = 300/g'      /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
    ##sudo sed -i 's/memory_limit = [0-9]\+M/memory_limit = 64M/g'                 /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
    sudo sed -i 's/upload_max_filesize = [0-9]\+M/upload_max_filesize = 50M/g'    /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
    sudo sed -i 's/post_max_size = [0-9]\+M/post_max_size = 50M/g'                /etc/php5/apache2/php.ini /etc/php5/cli/php.ini
    ##sudo sed -i 's/;error_log = filename/error_log = \/var\/log\/php-error.log/g'        /etc/php5/apache2/php.ini /etc/php5/cli/php.ini # php 5.2
    ##sudo sed -i 's/;error_log = php_errors.log/error_log = \/var\/log\/php-error.log/g'  /etc/php5/apache2/php.ini /etc/php5/cli/php.ini # php 5.3
    sudo sed -i 's/;date.timezone =/date.timezone = \"Europe\/Istanbul\"/g'    /etc/php5/apache2/php.ini /etc/php5/cli/php.ini

    # ----- Configure phpmyadmin -----
    # pma config here
}
function test_lamp() {
    # ----- test apache -----
    if ! wget -q "http://localhost"; then
        echo "Apache not running correctly. Exiting ..."
        exit 1
    fi
    rm index.html

    # ----- test php -----
    echo "<?php phpinfo(); ?>" > $DOCUMENT_ROOT/__info__.php
    if ! wget -q "http://localhost/__info__.php"; then
        echo "Cannot open __info__.php. Exiting..."
        rm __info__.php
        exit 1
    else
        if [[ $(wget -q -O - "http://localhost/__info__.php" | grep "PHP Version") == "" ]]
        then
            echo "PHP is not running correctly. Exiting ..."
            rm __info__.php
            exit 1
        fi
    fi
    rm __info__.php
}
function configs() {
    if [ ! -e "$CONFIGS" ]; then
        mkdir $CONFIGS

        #sudo chmod -R g+w /etc/apache2
        ln -s   /etc/apache2/apache2.conf       $CONFIGS/apache2.conf
        ln -s   /etc/apache2/httpd.conf         $CONFIGS/httpd.conf
        ln -s   /etc/apache2/ports.conf         $CONFIGS/ports.conf
        ln -s   /etc/apache2/sites-enabled/     $CONFIGS/apache-sites-enabled

        #sudo chmod -R g+w /etc/php5
        ln -s   /etc/php5/apache2/php.ini       $CONFIGS/php-apache.ini
        ln -s   /etc/php5/cli/php.ini           $CONFIGS/php-cli.ini

        #sudo chmod -R g+w /etc/mysql
        ln -s   /etc/mysql/my.cnf               $CONFIGS/mysql.cnf

        #sudo chmod g+w /etc/hosts
        ln -s   /etc/hosts                      $CONFIGS/hosts
    fi
}
function logs() {
    if [ ! -e "$LOGS" ]; then
        mkdir $LOGS

        ln -s   /var/log/apache2/error.log                  $LOGS/apache-error.log
        ln -s   /var/log/apache2/other_vhosts_access.log    $LOGS/apache-access.log
        ln -s   /var/log/php-error.log                      $LOGS/php-error.log
        ln -s   /var/log/mysql/error.log                    $LOGS/mysql-error.log
        ln -s   /var/log/mysql/mysql-slow.log               $LOGS/mysql-slow.log
    fi
}

sleep 2
echo -e "\n* Start installing lamp ..."
install_lamp
echo "* Lamp installed."
sleep 2

echo -e "\n* Configuring lamp ..."
configure_lamp
echo "* Lamp configured."
sleep 2

echo -e "\n* Restarting web server ..."
restart_web_server
echo "* Web server restarted."
sleep 2

echo -e "\n* Start testing lamp ..."
test_lamp
echo "* Lamp tested."

configs     # collect all config files in same directory
#sudo chown -R $USER:$USER $CONFIGS

echo "sudo chown -R $USER:$USER $CONFIGS"

logs        # collect all log files in same directory
#sudo chown -R $USER:$USER $LOGS
exit 0