FROM serversideup/php:8.4-fpm
WORKDIR "/application"

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
    opcache \
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

COPY php-ini-overrides.ini  /etc/php/8.4/fpm/conf.d/z-overrides.ini
COPY opcache-prod.ini       /etc/php/8.4/fpm/conf.d/z-opcache.ini
COPY php-fpm-pool-prod.conf /etc/php/8.4/fpm/pool.d/z-optimised.conf
