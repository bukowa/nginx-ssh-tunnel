
1. Make your domain configurable in digitalocean.
2. Run:
```bash
export DIGITALOCEAN_TOKEN=<token>
export DO_AUTH_TOKEN=$DIGITALOCEAN_TOKEN
export TF_VAR_server_name="*.example.com"
make deploy
make tunnel
```
