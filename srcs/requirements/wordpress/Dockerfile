FROM alpine:3.22

RUN apk update && apk add --no-cache \
    php82 \
    php82-fpm \
    php82-mysqli \
    php82-json \
    php82-openssl \
    php82-curl \
    php82-zlib \
    php82-xml \
    php82-phar \
    php82-intl \
    php82-dom \
    php82-xmlreader \
    php82-ctype \
    php82-mbstring \
    php82-gd \
    php82-session \
    php82-tokenizer \
    curl \
    mariadb-client

RUN curl -O https://wordpress.org/latest.tar.gz && \
    tar xf latest.tar.gz && \
    rm latest.tar.gz && \
    mkdir -p /var/www && \
    mv wordpress /var/www/html && \
    chown -R nobody:nobody /var/www/html

COPY conf/www.conf /etc/php82/php-fpm.d/www.conf
COPY tools/configure.sh /tmp/configure.sh

RUN chmod +x /tmp/configure.sh

EXPOSE 9000

ENTRYPOINT ["/tmp/configure.sh"]
