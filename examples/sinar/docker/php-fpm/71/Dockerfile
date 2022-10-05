FROM php:7.1.33-fpm

RUN apt-get update -y
RUN apt-get install -y git \
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
    unzip \
    libzip-dev \
    zip

RUN docker-php-ext-configure gd --with-freetype --with-jpeg

RUN docker-php-ext-install -j$(nproc) gd
RUN docker-php-ext-install bcmath pdo pdo_mysql mysqli

# install memcache by pecl
RUN pecl install memcached
RUN docker-php-ext-enable memcached

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