
deploy: apply
.PHONY: ssh tunnel apply destroy cleanup

apply:
	terraform apply --auto-approve --target=acme_registration.reg
	terraform apply --auto-approve --target=digitalocean_droplet.nginx_proxy
	terraform apply --auto-approve

cleanup:
	terraform destroy --auto-approve --target=digitalocean_record.domain
	terraform destroy --auto-approve --target=digitalocean_droplet.nginx_proxy

destroy:
	terraform destroy --auto-approve

ssh:
	ssh root@$(shell terraform output ip)

tunnel:
	autossh \
	-o ServerAliveInterval=30 \
	-o ServerAliveCountMax=1 \
	-M 0 -N -R $(shell terraform output --raw tunnel_port):localhost:80 root@$(shell terraform output --raw ip)
