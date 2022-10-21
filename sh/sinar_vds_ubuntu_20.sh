#!/bin/bash
sudo apt update
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository ppa:deadsnakes/ppa -y
sudo apt install python3.9 -y
#add-apt-repository --force-yes ppa:ondrej/php
add-apt-repository ppa:ondrej/php -y
apt upgrade -y
apt install libapache2-mod-php7.4 php7.4 php7.4-cli php7.4-common php7.4-curl php7.4-gd php7.4-imap php7.4-intl php7.4-mailparse php7.4-mbstring php7.4-mcrypt php7.4-mysql php7.4-opcache php7.4-pspell php7.4-psr php7.4-readline php7.4-redis php7.4-swoole php7.4-xml php7.4-zip php7.4-fpm mysql-server nginx git mc supervisor -y
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php  --install-dir=/bin/  --filename=composer
php -r "unlink('composer-setup.php');"
useradd -d /var/repo -m -G sudo www-root
read -sp 'DB Password: ' db_pass
echo ''
mysql --execute="CREATE USER 'www-root'@'localhost' IDENTIFIED BY '$db_pass';GRANT ALL PRIVILEGES ON * . * TO 'www-root'@'localhost'; FLUSH PRIVILEGES;"
bash ds --install-alias
#sudo -u www-root bash