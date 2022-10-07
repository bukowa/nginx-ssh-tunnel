#!/bin/sh
set -e

if [ -z "$SERVER" ]; then
  echo "\$SERVER is blank";
  exit 1
fi

envsubst '$TUNNEL_HOST $TUNNEL_PORT $SERVER' < /etc/nginx/nginx.conf.envsubst > /etc/nginx/nginx.conf
cat /etc/nginx/nginx.conf
