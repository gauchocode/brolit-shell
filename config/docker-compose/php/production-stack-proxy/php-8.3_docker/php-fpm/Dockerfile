FROM phpdockerio/php:8.2-fpm
WORKDIR "/application"

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \ 
        git \ 
        php8.3-amqp \
        php8.3-ast \
        php8.3-bcmath \
        php8.3-bz2 \
        php8.3-cgi \
        php8.3-dba \
        php8.3-gd \
        php8.3-gmagick \
        php8.3-gmp \
        php8.3-grpc \
        php8.3-http \
        php8.3-igbinary \
        php8.3-imagick \
        php8.3-imap \
        php8.3-inotify \
        php8.3-interbase \
        php8.3-intl \
        php8.3-lz4 \
        php8.3-mailparse \
        php8.3-mcrypt \
        php8.3-mysql \
        php8.3-oauth \
        php8.3-opentelemetry \
        php8.3-raphf \
        php8.3-redis \
        php8.3-soap \
        php8.3-solr \
        php8.3-sqlite3 \
        php8.3-ssh2 \
        php8.3-tidy \
        php8.3-uopz \
        php8.3-uploadprogress \
        php8.3-uuid \
        php8.3-vips \
        php8.3-xmlrpc \
        php8.3-xsl \
        php8.3-yac \
        php8.3-yaml \
        php8.3-zmq \
        php8.3-zstd \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
    
COPY php-ini-overrides.ini  /etc/php/8.3/fpm/conf.d/z-overrides.ini
COPY opcache-prod.ini       /etc/php/8.3/fpm/conf.d/z-opcache.ini
COPY php-fpm-pool-prod.conf /etc/php/8.3/fpm/pool.d/z-optimised.conf
