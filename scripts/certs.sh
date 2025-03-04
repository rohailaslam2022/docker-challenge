#!/usr/bin/env bash

if [ -n "$CERTS" ]; then
    if [ "$STAGING" = true ]; then
        certbot certonly --no-self-upgrade -n --text --standalone \
        --preferred-challenges http-01 \
        --staging \
        -d "$CERTS" --keep --expand --agree-tos --email "$EMAIL" \
        || exit 2
    else
        certbot certonly --no-self-upgrade -n --text --standalone \
        --preferred-challenges http-01 \
        -d "$CERTS" --keep --expand --agree-tos --email "$EMAIL" \
        || exit 1
    fi

    mkdir -p /etc/haproxy/certs
    for site in $(ls -1 /etc/letsencrypt/live | grep -v ^README$); do
        CERT_DIR="/etc/letsencrypt/live/$site"
        OUTPUT_FILE="/etc/haproxy/certs/haproxy.pem"  # Fixed filename

        if [ -f "$CERT_DIR/fullchain.pem" ] && [ -f "$CERT_DIR/privkey.pem" ]; then
            cat "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem" > "$OUTPUT_FILE"
            echo "Successfully created $OUTPUT_FILE for $site"
        else
            echo "Error: Certificate files not found in $CERT_DIR"
            exit 1
        fi
    done
fi

exit 
