FROM phpdockerio/php:8.0-fpm
WORKDIR "/application"

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \ 
        git \
        php8.0-raphf \ 
        php8.0-bz2 \ 
        php8.0-gd \ 
        php8.0-imagick \ 
        php8.0-imap \ 
        php8.0-intl \ 
        php8.0-mcrypt \ 
        php8.0-mysql \ 
        php8.0-oauth \ 
        php8.0-pgsql \ 
        php8.0-redis \ 
        php8.0-xdebug \ 
        php8.0-xmlrpc; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer    
COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer    
COPY php-ini-overrides.ini  /etc/php/8.0/fpm/conf.d/z-overrides.ini
COPY opcache-prod.ini       /etc/php/8.0/fpm/conf.d/z-opcache.ini
COPY php-fpm-pool-prod.conf /etc/php/8.0/fpm/pool.d/z-optimised.conf
