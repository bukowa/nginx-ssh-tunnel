#!/bin/sh
set -e

if [ -z "$SERVER" ]; then
  echo "\$SERVER is blank";
  exit 1
fi

envsubst '$TUNNEL_HOST $TUNNEL_PORT $SERVER' < /etc/nginx/nginx.conf.envsubst > /etc/nginx/nginx.conf
cat /etc/nginx/nginx.conf




ssl_certificate="/certs/live/$SERVER/fullchain.pem"
ssl_certificate_key="/certs/live/$SERVER/privkey.pem"

if ! [ -f "$ssl_certificate" ] || ! [ -f "$ssl_certificate_key" ]; then
  echo "Certificates not found, generating dummy certs so nginx can boot up..."
  mkdir -p tmp-certs12345612345 ; cd tmp-certs12345612345
  mkdir -p $(dirname "$ssl_certificate")
  mkdir -p $(dirname "$ssl_certificate_key")
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj "/CN=${SERVER}/O=${SERVER}" \
    -keyout "${ssl_certificate_key}" \
    -out "${ssl_certificate}"
fi
