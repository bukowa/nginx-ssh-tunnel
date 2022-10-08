
IP=$(shell terraform output ip)

deploy: apply

apply:
	terraform  apply --auto-approve

destroy:
	terraform destroy --auto-approve

.PHONY: ssh
ssh:
	ssh root@${IP}
