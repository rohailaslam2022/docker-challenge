FROM debian:buster-slim

# Install certbot, supervisor, and utilities
RUN apt-get update && apt-get install --no-install-recommends -yqq \
    gnupg \
    apt-transport-https \
    cron \
    wget \
    ca-certificates \
    curl \
    procps \
    certbot \
    supervisor \
    liblua5.3-0 \
    && apt-get clean autoclean && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Install HAProxy
RUN curl https://haproxy.debian.net/bernat.debian.org.gpg \
       | gpg --dearmor > /usr/share/keyrings/haproxy.debian.net.gpg \
    && echo deb "[signed-by=/usr/share/keyrings/haproxy.debian.net.gpg]" \
       http://haproxy.debian.net buster-backports-2.4 main \
       > /etc/apt/sources.list.d/haproxy.list \
    && apt-get update \
    && apt-get install -yqq haproxy=2.4.* \
    && apt-get clean autoclean && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files (excluding haproxy.cfg)
COPY conf/haproxy.cfg /etc/haproxy/haproxy.cfg
COPY conf/supervisord.conf /etc/supervisord.conf
COPY haproxy-acme-validation-plugin/acme-http01-webroot.lua /etc/haproxy
COPY scripts/cert-renewal-haproxy.sh /
COPY conf/crontab.txt /var/crontab.txt
COPY scripts/certs.sh /
COPY scripts/bootstrap.sh /
RUN sed -i 's/\r$//' /bootstrap.sh /certs.sh /cert-renewal-haproxy.sh && \
    chmod +x /bootstrap.sh /certs.sh /cert-renewal-haproxy.sh

# Fix crontab and install it
RUN echo "" >> /var/crontab.txt && crontab /var/crontab.txt && chmod 600 /etc/crontab \
    && rm -f /etc/cron.d/certbot \
    && rm -f /etc/cron.hourly/* \
    && rm -f /etc/cron.daily/* \
    && rm -f /etc/cron.weekly/* \
    && rm -f /etc/cron.monthly/*

# Create jail directory

RUN mkdir -p /run/haproxy && chown haproxy:haproxy /run/haproxy

RUN mkdir /jail

EXPOSE 80 443
VOLUME /etc/letsencrypt
ENV STAGING=false
ENTRYPOINT ["/bootstrap.sh"]
