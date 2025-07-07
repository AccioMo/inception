FROM alpine:latest

RUN apk update && apk add --no-cache mariadb mariadb-client

RUN mkdir -p /run/mysqld
RUN chown -R mysql:mysql /run/mysqld

COPY conf/my.cnf /etc/my.cnf
COPY tools/configure.sh /tmp/configure.sh

RUN chmod +x /tmp/configure.sh

EXPOSE 3306

ENTRYPOINT ["/tmp/configure.sh"]
