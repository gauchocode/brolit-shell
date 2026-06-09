FROM serversideup/php:8.5-fpm
WORKDIR "/wordpress"

USER root

RUN install-php-extensions \
    bcmath \
    bz2 \
    exif \
    gd \
    imagick \
    imap \
    intl \
    mysqli \
    soap \
    xsl \
    yaml

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \
        git; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

USER www-data

COPY --chown=www-data:www-data php-ini-overrides.ini  /usr/local/etc/php/conf.d/z-overrides.ini
COPY --chown=www-data:www-data opcache-prod.ini       /usr/local/etc/php/conf.d/z-opcache.ini
COPY --chown=www-data:www-data php-fpm-pool-prod.conf /usr/local/etc/php-fpm.d/z-optimised.conf
