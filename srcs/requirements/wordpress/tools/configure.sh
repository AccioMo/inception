#!/bin/sh

if [ ! -f "/var/www/html/wp-config.php" ]; then
    cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
    
    sed -i "s/database_name_here/$DB_NAME/g" /var/www/html/wp-config.php
    sed -i "s/username_here/$DB_USER/g" /var/www/html/wp-config.php
    sed -i "s/password_here/$DB_PASSWORD/g" /var/www/html/wp-config.php
    sed -i "s/localhost/mariadb/g" /var/www/html/wp-config.php
    
    # Generate WordPress salts
    curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/html/wp-config.php
fi

exec php-fpm8 -F
