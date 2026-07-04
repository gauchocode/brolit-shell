FROM serversideup/php:8.4-fpm
WORKDIR "/wordpress"

# Switch to root to install extensions
USER root

# Install additional PHP extensions using install-php-extensions
# mysqli is REQUIRED by WordPress and must be installed explicitly
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

# Install additional system packages if needed
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

# Switch back to the default user (www-data for serversideup/php)
USER www-data

COPY --chown=www-data:www-data php-ini-overrides.ini  /usr/local/etc/php/conf.d/z-overrides.ini
COPY --chown=www-data:www-data opcache-prod.ini       /usr/local/etc/php/conf.d/z-opcache.ini
COPY --chown=www-data:www-data php-fpm-pool-prod.conf /usr/local/etc/php-fpm.d/z-optimised.conf
