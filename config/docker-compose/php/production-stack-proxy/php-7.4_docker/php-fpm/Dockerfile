FROM phpdockerio/php:7.4-fpm
WORKDIR "/application"

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \ 
        git \ 
        php7.4-bcmath \ 
        php7.4-bz2 \ 
        php7.4-intl \ 
        php7.4-imap \ 
        php7.4-imagick \ 
        php7.4-mysql \ 
        php7.4-yaml \
        php7.4-gd \
        php7.4-redis; \ 
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer
COPY php-ini-overrides.ini  /etc/php/7.4/fpm/conf.d/z-overrides.ini
COPY opcache-prod.ini       /etc/php/7.4/fpm/conf.d/z-opcache.ini
COPY php-fpm-pool-prod.conf /etc/php/7.4/fpm/pool.d/z-optimised.conf
