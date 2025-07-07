#!/bin/bash

# Inception Project Setup Script
# Creates directory structure and template files for the 42 Inception project

# Check if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "Error: This script should not be run as root. Run as a normal user."
    exit 1
fi

# Get current directory
PROJECT_DIR="$(pwd)/inception"
SRCS_DIR="$PROJECT_DIR/srcs"

# Check if directory already exists
if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Directory $PROJECT_DIR already exists."
    exit 1
fi

# Create directory structure
echo "Creating project structure in $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"
mkdir -p "$SRCS_DIR"
mkdir -p "$SRCS_DIR/secrets"
mkdir -p "$SRCS_DIR/requirements/nginx/conf"
mkdir -p "$SRCS_DIR/requirements/nginx/tools"
mkdir -p "$SRCS_DIR/requirements/mariadb/conf"
mkdir -p "$SRCS_DIR/requirements/mariadb/tools"
mkdir -p "$SRCS_DIR/requirements/wordpress/conf"
mkdir -p "$SRCS_DIR/requirements/wordpress/tools"
mkdir -p "$SRCS_DIR/requirements/bonus"

# Create Makefile
echo "Creating Makefile..."
cat > "$PROJECT_DIR/Makefile" << 'EOL'
.PHONY: all build up down clean fclean re

all: build up

build:
	@docker-compose -f ./srcs/docker-compose.yml build

up:
	@docker-compose -f ./srcs/docker-compose.yml up -d

down:
	@docker-compose -f ./srcs/docker-compose.yml down

clean: down
	@docker system prune -a --force

fclean: clean
	@sudo rm -rf /home/${USER}/data

re: fclean all
EOL

# Create docker-compose.yml
echo "Creating docker-compose.yml..."
cat > "$SRCS_DIR/docker-compose.yml" << 'EOL'
version: '3'

services:
  nginx:
    build:
      context: ./requirements/nginx
    container_name: nginx
    depends_on:
      - wordpress
    ports:
      - "443:443"
    networks:
      - inception_network
    restart: always

  mariadb:
    build:
      context: ./requirements/mariadb
    container_name: mariadb
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
      - MYSQL_DATABASE=${DB_NAME}
      - MYSQL_USER=${DB_USER}
      - MYSQL_PASSWORD=${DB_PASSWORD}
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - inception_network
    restart: always

  wordpress:
    build:
      context: ./requirements/wordpress
    container_name: wordpress
    depends_on:
      - mariadb
    environment:
      - WORDPRESS_DB_HOST=mariadb
      - WORDPRESS_DB_NAME=${DB_NAME}
      - WORDPRESS_DB_USER=${DB_USER}
      - WORDPRESS_DB_PASSWORD=${DB_PASSWORD}
    volumes:
      - wordpress_data:/var/www/html
    networks:
      - inception_network
    restart: always

volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      device: /home/${USER}/data/mariadb
      o: bind
  wordpress_data:
    driver: local
    driver_opts:
      type: none
      device: /home/${USER}/data/wordpress
      o: bind

networks:
  inception_network:
    driver: bridge
EOL

# Create .env file
echo "Creating .env file..."
cat > "$SRCS_DIR/.env" << 'EOL'
# Domain configuration
DOMAIN_NAME=your_login.42.fr

# Database configuration
DB_NAME=wordpress
DB_USER=wp_user
DB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)
DB_ROOT_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)
EOL

# Create Nginx Dockerfile
echo "Creating Nginx Dockerfile..."
cat > "$SRCS_DIR/requirements/nginx/Dockerfile" << 'EOL'
FROM alpine:3.16

RUN apk update && apk add --no-cache nginx openssl

# Create directory for SSL certificates
RUN mkdir -p /etc/nginx/ssl

# Generate SSL certificate
RUN openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/nginx.key \
    -out /etc/nginx/ssl/nginx.crt \
    -subj "/C=FR/ST=Paris/L=Paris/O=42/OU=42/CN=${DOMAIN_NAME}"

COPY conf/nginx.conf /etc/nginx/http.d/default.conf

EXPOSE 443

CMD ["nginx", "-g", "daemon off;"]
EOL

# Create Nginx configuration
mkdir -p "$SRCS_DIR/requirements/nginx/conf"
cat > "$SRCS_DIR/requirements/nginx/conf/nginx.conf" << 'EOL'
server {
    listen 443 ssl;
    server_name ${DOMAIN_NAME};

    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass wordpress:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
    }
}
EOL

# Create MariaDB Dockerfile
echo "Creating MariaDB Dockerfile..."
cat > "$SRCS_DIR/requirements/mariadb/Dockerfile" << 'EOL'
FROM alpine:3.16

RUN apk update && apk add --no-cache mariadb mariadb-client

RUN mkdir -p /run/mysqld
RUN chown -R mysql:mysql /run/mysqld

COPY conf/my.cnf /etc/my.cnf
COPY tools/configure.sh /tmp/configure.sh

RUN chmod +x /tmp/configure.sh

EXPOSE 3306

ENTRYPOINT ["/tmp/configure.sh"]
EOL

# Create MariaDB configuration
mkdir -p "$SRCS_DIR/requirements/mariadb/conf"
cat > "$SRCS_DIR/requirements/mariadb/conf/my.cnf" << 'EOL'
[mysqld]
user = mysql
port = 3306
socket = /run/mysqld/mysqld.sock
bind-address = 0.0.0.0
skip-networking = off
datadir = /var/lib/mysql
max_allowed_packet = 16M
EOL

# Create MariaDB configure script
mkdir -p "$SRCS_DIR/requirements/mariadb/tools"
cat > "$SRCS_DIR/requirements/mariadb/tools/configure.sh" << 'EOL'
#!/bin/sh

if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --datadir=/var/lib/mysql
    
    /usr/bin/mysqld --user=mysql --bootstrap << EOF
USE mysql;
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$DB_ROOT_PASSWORD';
CREATE DATABASE $DB_NAME;
CREATE USER '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF
fi

exec /usr/bin/mysqld --user=mysql
EOL
chmod +x "$SRCS_DIR/requirements/mariadb/tools/configure.sh"

# Create WordPress Dockerfile
echo "Creating WordPress Dockerfile..."
cat > "$SRCS_DIR/requirements/wordpress/Dockerfile" << 'EOL'
FROM alpine:3.16

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
EOL

# Create WordPress PHP-FPM configuration
mkdir -p "$SRCS_DIR/requirements/wordpress/conf"
cat > "$SRCS_DIR/requirements/wordpress/conf/www.conf" << 'EOL'
[www]
user = nobody
group = nobody
listen = 0.0.0.0:9000
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
EOL

# Create WordPress configure script
mkdir -p "$SRCS_DIR/requirements/wordpress/tools"
cat > "$SRCS_DIR/requirements/wordpress/tools/configure.sh" << 'EOL'
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
EOL
chmod +x "$SRCS_DIR/requirements/wordpress/tools/configure.sh"

# Create secrets files
echo "Creating secrets files..."
echo "WordPress admin credentials will be generated during first run" > "$SRCS_DIR/secrets/credentials.txt"
echo "DB_USER=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 12)" > "$SRCS_DIR/secrets/db_credentials.txt"
echo "DB_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)" >> "$SRCS_DIR/secrets/db_credentials.txt"
echo "DB_ROOT_PASSWORD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 20)" > "$SRCS_DIR/secrets/db_root_password.txt"

# Create .dockerignore files
echo "Creating .dockerignore files..."
for dir in nginx mariadb wordpress; do
    cat > "$SRCS_DIR/requirements/$dir/.dockerignore" << 'EOL'
.git
.gitignore
*.md
*.txt
EOL
done

# Create data directories
echo "Creating data directories..."
mkdir -p "/home/${USER}/data/mariadb"
mkdir -p "/home/${USER}/data/wordpress"

# Set permissions
echo "Setting permissions..."
chmod -R 755 "/home/${USER}/data"
chown -R $USER:$USER "/home/${USER}/data"
chown -R $USER:$USER "$PROJECT_DIR"

echo "Project setup complete!"
echo "Next steps:"
echo "1. Edit the .env file in srcs/ to set your domain name (your_login.42.fr)"
echo "2. Review all configuration files and adjust as needed"
echo "3. Run 'make' from the project root to build and start the containers"
echo "4. Access your WordPress site at https://your_login.42.fr (you'll need to add this domain to your /etc/hosts file)"