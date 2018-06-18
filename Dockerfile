FROM php:7.1-alpine

LABEL maintener="Vincent Fages <vfagesgo@gmail.com>"
LABEL contributor="Vincent Fages <vfagesgo@gmail.com>"

#/etc/nginx/conf.d/default.conf

# fix a problem--#397, change application source from dl-cdn.alpinelinux.org to aliyun source.
#RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/' /etc/apk/repositories

RUN apk update \
    && apk upgrade \
    && apk add --no-cache bash nginx \
    && rm /etc/nginx/conf.d/default.conf \
    && echo "upstream php-upstream { server 127.0.0.1:9000; }" > /etc/nginx/conf.d/upstream.conf

#ADD http://php.codecasts.rocks/php-alpine.rsa.pub /etc/apk/keys/php-alpine.rsa.pub
#RUN echo "@php http://php.codecasts.rocks/v3.6/php-7.1" >> /etc/apk/repositories
# Install packages
RUN apk add --no-cache \
php7 \
php7-common \
php7-ctype \
php7-curl \
php7-fileinfo \
php7-fpm \
php7-pdo \
php7-pdo_mysql \
php7-mcrypt \
php7-mbstring \
php7-openssl \
php7-json \
php7-phar \
php7-zip \
php7-dom \
php7-session \
php7-tokenizer \
php7-xml \
php7-xmlwriter \
php7-zlib \
curl \
zip

#Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer

# Install MySql
RUN apk add --update mysql mysql-client && rm -f /var/cache/apk/*

RUN chown -R mysql:root /var/lib/mysql/

ADD ./conf/my.cnf /etc/mysql/conf.d/my.cnf

# Configure nginx
COPY ./conf/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY ./conf/php-fpm.conf /etc/php7/php-fpm.d/php-fpm.conf
COPY ./conf/php.ini /etc/php7/php.ini

COPY ./conf/dockinit.sh /etc/docker/dockinit.sh
RUN chmod +x /etc/docker/dockinit.sh

# Configure supervisord
# Install supervisord
RUN apk --no-cache add supervisor
COPY ./conf/supervisord.conf /etc/supervisord.conf

RUN apk del curl git

VOLUME /var/log
VOLUME /var/www

WORKDIR /var/www

EXPOSE 80 443 3306
ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
