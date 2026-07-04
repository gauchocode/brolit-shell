FROM serversideup/php:8.5-fpm
WORKDIR "/application"

USER root

RUN install-php-extensions \
    mysqli \
    pdo_mysql \
    gd \
    zip \
    bcmath \
    intl \
    exif \
    imagick \
    opcache \
    redis \
    soap \
    yaml \
    bz2 \
    imap \
    xsl \
    pcntl

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \
        git \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libyaml-dev \
        libzip-dev; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

USER www-data

COPY --chown=www-data:www-data php-ini-overrides.ini  /etc/php/8.5/fpm/conf.d/z-overrides.ini
COPY --chown=www-data:www-data opcache-prod.ini       /etc/php/8.5/fpm/conf.d/z-opcache.ini
COPY --chown=www-data:www-data php-fpm-pool-prod.conf /etc/php/8.5/fpm/pool.d/z-optimised.conf
