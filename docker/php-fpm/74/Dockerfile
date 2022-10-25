FROM php:7.4.0-fpm

RUN apt-get update -y
RUN apt-get install sudo
RUN sudo apt-get update  -y

# На момент 07.10.2022 `отвалился` пакет default-mysql-client. Приянто решение о замене путей скачивания
RUN sudo apt-get install -y python3-pip
RUN sudo pip3 install apt-mirror-updater
RUN sudo apt-mirror-updater -c "http://ftp.ru.debian.org/debian"
RUN sudo apt-get update  -y

RUN sudo apt-get install -y --fix-missing git \
    software-properties-common \
    mc \
    sudo \
    vim \
    cron \
    make \
    systemd \
    wget \
    build-essential \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpng-dev \
    curl \
    sendmail \
    libcurl4 \
    libz-dev \
    libcurl4-openssl-dev \
    zlib1g-dev \
    libicu-dev \
    libmemcached-dev \
    memcached \
    default-mysql-client \
    libmagickwand-dev \
    libwebp-dev \
    unzip \
    libzip-dev \
    zip \
    apache2-utils

RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp

RUN docker-php-ext-install -j$(nproc) gd
RUN docker-php-ext-install bcmath pdo pdo_mysql mysqli

# install memcache by pecl
RUN pecl install memcached
RUN docker-php-ext-enable memcached

# настройка почты
RUN sudo sendmailconfig

# install memcache
# https://serverfault.com/questions/65092/unable-to-load-memcache-so-extension
RUN mkdir /var/www/memcache && cd /var/www/memcache && wget http://pecl.php.net/get/memcache && tar -zxvf memcache && cd memcache-8.0 && phpize && ./configure --enable-memcache && make && make install && rm -rf /var/www/memcache

# for configure email's
RUN rm -rf /var/lib/apt/lists/*

#composer install -start
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php -r "if (hash_file('sha384', 'composer-setup.php') === '55ce33d7678c5a611085589f1f3ddf8b3c52d662cd01d4ba75c0ee0459970c2200a51f492d557530c71c15d8dba01eae') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN sudo mv composer.phar /usr/local/bin/composer
#composer install -end

# cron's works
# Add crontab file in the cron directory
#ADD cron/root /etc/cron.d/hello-cron

# Give execution rights on the cron job
#RUN chmod 0644 /etc/cron.d/hello-cron

# Apply cron job
#RUN crontab /etc/cron.d/hello-cron

# Create the log file to be able to run tail
#RUN touch /var/log/cron.log

# Run the command on container startup
#CMD cron && tail -f /var/log/cron.log
#CMD cron
