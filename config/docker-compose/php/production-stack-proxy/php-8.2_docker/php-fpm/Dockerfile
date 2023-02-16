FROM phpdockerio/php:8.2-fpm
WORKDIR "/application"

RUN apt-get update; \
    apt-get -y --no-install-recommends install \
        vim \ 
        git \ 
        php8.2-bcmath \ 
        php8.2-bz2 \ 
        php8.2-gd \ 
        php8.2-gmagick \ 
        php8.2-gmp \ 
        php8.2-grpc \ 
        php8.2-imap \ 
        php8.2-mysql \ 
        php8.2-pgsql \ 
        php8.2-redis \ 
        php8.2-tidy \ 
        php8.2-xdebug \ 
        php8.2-xmlrpc \ 
        php8.2-yaml \ 
        php8.2-zstd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*