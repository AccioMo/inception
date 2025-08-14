#!/bin/bash

echo "Waiting for database connection..."
until nc -z mariadb 3306; do
   sleep 2
done

if [ ! -f /var/www/html/wp-config.php ]; then
   cat > /var/www/html/wp-config.php << EOF
<?php
define('DB_NAME', '${DB_NAME}');
define('DB_USER', '${DB_USER}');
define('DB_PASSWORD', '${DB_PASSWORD}');
define('DB_HOST', 'mariadb:3306');
\$table_prefix = 'wp_';
if ( !defined('ABSPATH') )
   define('ABSPATH', dirname(__FILE__) . '/');
require_once(ABSPATH . 'wp-settings.php');
EOF
fi

if ! wp core is-installed --allow-root --path=/var/www/html 2>/dev/null; then
   wp core install \
       --url="${DOMAIN_NAME}" \
       --title="WordPress Site" \
       --admin_user="${WP_ADMIN_USER}" \
       --admin_password="${WP_ADMIN_PASSWORD}" \
       --admin_email="${WP_ADMIN_EMAIL}" \
       --allow-root \
       --path=/var/www/html
fi

chown -R www-data:www-data /var/www/html

exec php-fpm8.2 --nodaemonize
