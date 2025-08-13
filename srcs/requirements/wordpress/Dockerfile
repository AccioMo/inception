FROM debian:bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    php8.2-fpm \
    php8.2-mysqli \
    php8.2-curl \
    php8.2-gd \
    php8.2-intl \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    mariadb-client \
    curl \
    ca-certificates \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

RUN curl -O https://wordpress.org/latest.tar.gz && \
    tar xf latest.tar.gz && \
    rm latest.tar.gz && \
    mkdir -p /var/www && \
    mv wordpress /var/www/html && \
    chown -R www-data:www-data /var/www/html && \
    chmod -R 755 /var/www/html

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/configure.sh /tmp/configure.sh
RUN chmod +x /tmp/configure.sh

EXPOSE 9000
ENTRYPOINT ["/tmp/configure.sh"]