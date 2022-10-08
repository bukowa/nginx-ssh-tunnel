
IP=$(shell terraform output ip)

deploy: apply

apply:
	terraform apply --auto-approve --target=digitalocean_droplet.nginx_proxy
	terraform apply --auto-approve

destroy:
	terraform destroy --auto-approve

.PHONY: ssh tunnel apply destroy
ssh:
	ssh root@${IP}

tunnel:
	autossh \
	-o ServerAliveInterval=30 \
	-o ServerAliveCountMax=1 \
	-M 0 -N -R $(shell terraform output --raw tunnel_port):localhost:80 root@${IP}
