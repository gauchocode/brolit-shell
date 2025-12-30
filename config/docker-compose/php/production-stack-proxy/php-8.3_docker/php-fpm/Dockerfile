FROM serversideup/php:8.3-fpm
WORKDIR "/application"

# Switch to root to install extensions
USER root

# Install additional PHP extensions using install-php-extensions
# mysqli, pdo, pdo_mysql, zip, opcache are already included in the base image
RUN install-php-extensions \
    bcmath \
    bz2 \
    exif \
    gd \
    intl \
    redis \
    imagick \
    imap \
    soap \
    xsl \
    zip

# Install additional system packages if needed
RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \
        git \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        libzip-dev; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Switch back to the default user (www-data for serversideup/php)
USER www-data

COPY --chown=www-data:www-data php-ini-overrides.ini  /etc/php/8.3/fpm/conf.d/z-overrides.ini
COPY --chown=www-data:www-data opcache-prod.ini       /etc/php/8.3/fpm/conf.d/z-opcache.ini
COPY --chown=www-data:www-data php-fpm-pool-prod.conf /etc/php/8.3/fpm/pool.d/z-optimised.conf
