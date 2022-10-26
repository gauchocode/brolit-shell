FROM phpdockerio/php:8.1-fpm
WORKDIR "/wordpress"

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        php8.1-bcmath \ 
        php8.1-bz2 \ 
        php8.1-cgi \ 
        php8.1-gd \ 
        php8.1-grpc \ 
        php8.1-http \ 
        php8.1-imagick \ 
        php8.1-imap \ 
        php8.1-inotify \ 
        php8.1-lz4 \ 
        php8.1-mcrypt \ 
        php8.1-mysql \ 
        php8.1-redis \ 
        php8.1-xmlrpc \ 
        php8.1-yaml \ 
        php8.1-zstd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*
