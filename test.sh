#!/bin/bash

# GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)
# Copyright (C) 2020 Free Software Foundation, Inc.
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
#
# This is free software; you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.

set -e
source funcs.sh

# docker images
IMAGE_TAG=testsshtunnel
OPENSSH_TAG="openssh_sshtunnel"

# Docker Containers
CONT_CLIENT="just_a_client"
CONT_DESTINATION="just_a_destination"
CONT_PROXY="just_a_proxy"
CONT_SSHKEYGEN="just_a_ssh_gen_name"
CONT_SSHTUNNEL="just_a_ssh_tunnel"
CONT_SSHSERVER="just_a_ssh_server"

# Docker Connection
NETWORK_NAME="just_a_proxy_client_network"
VOLUME_NAME="just_a_proxy_client_volume"

CONTAINERS=(
  "${CONT_CLIENT}" "${CONT_DESTINATION}" "${CONT_PROXY}"
  "${CONT_SSHKEYGEN}" "${CONT_SSHSERVER}" "${CONT_SSHTUNNEL}"
)
VOLUMES=(
  "${VOLUME_NAME}"
)
NETWORKS=(
  "${NETWORK_NAME}"
)


# Do not override anything on the host.
# Run `docker inspect` on these resources.
# If any of these resources exists, quit.
if isInspectable "${CONTAINERS[@]}" "${VOLUMES[@]}" "${NETWORKS[@]}"; then
  FATAL "Some resources exist";
fi


# Build docker image used by the client
# that actually tunnels the traffic.
INFO "Building docker image for ssh tunnel..."
IMAGE_SSHTUNNEL=$(docker build -q - <<EOF
FROM alpine
RUN apk add openssh autossh
EXPOSE 5000
EOF
)

# Build nginx proxy docker container.
INFO "Building docker image for nginx proxy..."
IMAGE_PROXY=$(docker build -q .)

# Remove all resources created in this script
function cleanup() {
  set +e
  INFO "Trapped... last exit code: $?"
  INFO "Cleaning up..."
  forEach "container rm -f" "${CONTAINERS[@]}"
  forEach "network rm" "${NETWORKS[@]}"
  forEach "volume rm -f" "${VOLUMES[@]}"
  INFO "Cleaned up..."
}

# set trap
trap cleanup 0

# create network and volume
docker network create ${NETWORK_NAME}
docker volume create ${VOLUME_NAME}


echo "Generating ssh keys..."
docker run --rm \
  --volume=${VOLUME_NAME}:/ssh_keys \
  --name=${CONT_SSHKEYGEN} \
  "${IMAGE_SSHTUNNEL}" \
  ssh-keygen -q -N "" -f /ssh_keys/id_rsa

exit 1

echo "Running ssh server..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/ssh_keys \
  -e PUBLIC_KEY_FILE=/ssh_keys/id_rsa.pub \
  -e USER_NAME=dev \
  -e DOCKER_MODS=linuxserver/mods:openssh-server-ssh-tunnel \
  -p 5000 \
  --name=${CONT_SSHSERVER} \
  linuxserver/openssh-server &

echo "Creating destination container..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --name=${CONT_DESTINATION} \
  quay.io/k8start/http-headers:0.1.1 \
  \
  --port=9000 &

sleep 5
echo "Running ssh tunnel..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/ssh_keys \
  --name=${CONT_SSHTUNNEL} \
  ${OPENSSH_TAG} \
    autossh -M 0 -N -o StrictHostKeyChecking=no \
    -i /ssh_keys/id_rsa -p 2222 \
    -R 0.0.0.0:5000:${CONT_DESTINATION}:9000 dev@${CONT_SSHSERVER} &

sleep 5
echo "Creating proxy container..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/certs/live/${SERVER} \
  -e SERVER=${CONT_PROXY} \
  -e TUNNEL_HOST=${CONT_SSHSERVER} \
  -e TUNNEL_PORT=5000 \
  --name=${CONT_PROXY} \
  ${IMAGE_TAG} &

sleep 5
echo "Running client waiting to be tunneled..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/certs/live/${SERVER} \
  --name=${CONT_CLIENT} \
  curlimages/curl \
  \
  curl --fail-with-body -v -L ${CONT_PROXY} \
    --cacert /certs/live/${SERVER}/fullchain.pem

echo "Looks like it works..."
