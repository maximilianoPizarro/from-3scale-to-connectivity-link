FROM registry.access.redhat.com/ubi8/httpd-24:latest

COPY proxy.conf /etc/httpd/conf.d/proxy.conf
COPY index.html /var/www/html/index.html

EXPOSE 8080

USER 1001
