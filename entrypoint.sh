#!/bin/sh
set -x

if [ -z "$SERVER" ]; then
  echo "\$SERVER is blank";
  exit 1
fi

if [ -z "$SSL_CERT_PATH" ] || [ -z "$SSL_KEY_PATH" ]; then
  export SSL_CERT_PATH="/certs/live/$SERVER/fullchain.pem"
  export SSL_KEY_PATH="/certs/live/$SERVER/privkey.pem"
fi

if ! [ -f "$SSL_CERT_PATH" ] || ! [ -f "$SSL_KEY_PATH" ]; then

  if [ -z "$SUBJECT" ]; then
    SUBJECT=$SERVER
  fi

  if [ -z "$ALTNAME" ]; then
    ALTNAME=$SERVER
  fi

  echo "Certificates not found, generating dummy certs so nginx can boot up..."
  mkdir -p $(dirname "$SSL_CERT_PATH")
  mkdir -p $(dirname "$SSL_KEY_PATH")
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -subj "/CN=${SUBJECT}/O=${SUBJECT}" \
    -addext "subjectAltName = DNS:${ALTNAME}, DNS:${SERVER}" \
    -out "${SSL_CERT_PATH}" \
    -keyout "${SSL_KEY_PATH}"
fi

envsubst '$TUNNEL_HOST $TUNNEL_PORT $SERVER $SSL_KEY_PATH $SSL_CERT_PATH' < /etc/nginx/nginx.conf.envsubst > /etc/nginx/nginx.conf
cat /etc/nginx/nginx.conf
