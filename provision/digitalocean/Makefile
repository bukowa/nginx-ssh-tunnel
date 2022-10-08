
IP=$(shell terraform output ip)

deploy: apply

apply:
	terraform apply --auto-approve --target=acme_registration.reg
	terraform apply --auto-approve --target=digitalocean_droplet.nginx_proxy
	terraform apply --auto-approve

destroy:
	terraform destroy --auto-approve --target=digitalocean_record.domain
	terraform destroy --auto-approve --target=digitalocean_droplet.nginx_proxy

cleanup:
	terraform destroy --auto-approve


.PHONY: ssh tunnel apply destroy cleanup

ssh:
	ssh root@${IP}

tunnel:
	autossh \
	-o ServerAliveInterval=30 \
	-o ServerAliveCountMax=1 \
	-M 0 -N -R $(shell terraform output --raw tunnel_port):localhost:80 root@${IP}
