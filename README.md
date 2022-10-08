
Tunnel http(s) traffic from internet facing endpoint into your machine via SSH.

I use it to redirect http traffic from server into localhost port 80, for example;
pass all traffic landing on `*.example.com` to `localhost:80`:

Server:
```bash
docker run \
  --restart=always \
  --network=host \
  --volume=$PWD/certs:/certs \
  -e SERVER="*.example.com" \
  -e TUNNEL_PORT=5600 \
  -e TUNNEL_HOST="localhost" \
  -d \
  --name=http-proxy \
  \
  quay.io/k8start/nginx-ssh-tunnel \
  \
  && \
  docker logs -f http-proxy
```

Localhost:

ssh:
```bash
ssh -R 5600:localhost:80 <user>@<server>
```
autossh:
```bash
autossh -M 0 -N -R 5000:localhost:80 <user>@<server>
```
