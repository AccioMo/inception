FROM alpine:latest

RUN apk update && apk add --no-cache \
    php8 \
    php8-fpm \
    php8-mysqli \
    php8-json \
    php8-openssl \
    php8-curl \
    php8-zlib \
    php8-xml \
    php8-phar \
    php8-intl \
    php8-dom \
    php8-xmlreader \
    php8-ctype \
    php8-mbstring \
    php8-gd \
    php8-session \
    php8-tokenizer \
    curl \
    mariadb-client

RUN curl -O https://wordpress.org/latest.tar.gz && \
    tar xf latest.tar.gz && \
    rm latest.tar.gz && \
    mv wordpress /var/www/html && \
    chown -R nobody:nobody /var/www/html

COPY conf/www.conf /etc/php8/php-fpm.d/www.conf
COPY tools/configure.sh /tmp/configure.sh

RUN chmod +x /tmp/configure.sh

EXPOSE 9000

ENTRYPOINT ["/tmp/configure.sh"]
