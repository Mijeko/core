FROM php:7.3.33-fpm

RUN apt-get update \
&& docker-php-ext-install pdo pdo_mysql mysqli

RUN apt install -y sudo
RUN apt update
RUN sudo apt install -y vim make make systemd wget


RUN apt-get update && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd