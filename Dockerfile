FROM nginx:alpine
RUN apk add openssl
ENV TUNNEL_HOST="localhost"
ENV TUNNEL_PORT="5055"
ENV SERVER=""
COPY entrypoint.sh /docker-entrypoint.d
COPY nginx.conf /etc/nginx/nginx.conf.envsubst
