FROM phpdockerio/php:7.4-fpm
WORKDIR "/wordpress"

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        php7.4-bcmath \ 
        php7.4-bz2 \ 
        php7.4-imap \ 
        php7.4-imagick \ 
        php7.4-mysql \ 
        php7.4-redis \ 
        php7.4-yaml; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
