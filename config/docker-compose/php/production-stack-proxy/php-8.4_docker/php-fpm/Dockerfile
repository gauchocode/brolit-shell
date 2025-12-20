FROM phpdockerio/php:8.4-fpm
WORKDIR "/application"

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \ 
        git \ 
        php8.4-amqp \
        php8.4-ast \
        php8.4-bcmath \
        php8.4-bz2 \
        php8.4-cgi \
        php8.4-dba \
        php8.4-gd \
        php8.4-gmagick \
        php8.4-gmp \
        php8.4-grpc \
        php8.4-http \
        php8.4-igbinary \
        php8.4-imagick \
        php8.4-imap \
        php8.4-inotify \
        php8.4-interbase \
        php8.4-intl \
        php8.4-lz4 \
        php8.4-mailparse \
        php8.4-mcrypt \
        php8.4-mysql \
        php8.4-oauth \
        php8.4-opentelemetry \
        php8.4-raphf \
        php8.4-redis \
        php8.4-soap \
        php8.4-solr \
        php8.4-sqlite3 \
        php8.4-ssh2 \
        php8.4-tidy \
        php8.4-uopz \
        php8.4-uploadprogress \
        php8.4-uuid \
        php8.4-vips \
        php8.4-xmlrpc \
        php8.4-xsl \
        php8.4-yac \
        php8.4-yaml \
        php8.4-zmq \
        php8.4-zstd \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
    
COPY php-ini-overrides.ini  /etc/php/8.4/fpm/conf.d/z-overrides.ini
COPY opcache-prod.ini       /etc/php/8.4/fpm/conf.d/z-opcache.ini
COPY php-fpm-pool-prod.conf /etc/php/8.4/fpm/pool.d/z-optimised.conf
