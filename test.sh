#!/bin/bash

# GNU bash, version 5.1.16(1)-release (x86_64-pc-linux-gnu)
# Copyright (C) 2020 Free Software Foundation, Inc.
# License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
#
# This is free software; you are free to change and redistribute it.
# There is NO WARRANTY, to the extent permitted by law.

set -e
source funcs.sh

CONT_CLIENT="just_a_client"
CONT_DESTINATION="just_a_destination"
CONT_PROXY="just_a_proxy"
CONT_SSHKEYGEN="just_a_ssh_gen_name"
CONT_SSHTUNNEL="just_a_ssh_tunnel"
CONT_SSHSERVER="just_a_ssh_server"

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

PULL_IMAGES=(
  "alpine" "nginx:alpine"
  "quay.io/k8start/http-headers:1.0.0"
  "linuxserver/openssh-server:9.0_p1-r2-ls94"
)

# Remove all resources created in this script
function cleanup() {
  INFO "Trapped... last exit code: $?"
  INFO "Cleaning up..."
  forEach "container rm -f" "${CONTAINERS[@]}"
  forEach "network rm" "${NETWORKS[@]}"
  forEach "volume rm -f" "${VOLUMES[@]}"
  INFO "Cleaned up..."
}

# Do not override anything on the host.
# Run `docker inspect` on these resources.
# If any of these resources exists, quit.
if isInspectable "${CONTAINERS[@]}" "${VOLUMES[@]}" "${NETWORKS[@]}"; then
  if [[ $FORCE_CLEANUP == "1" ]]; then
    cleanup
  else
    FATAL "Some resources exist";
  fi
fi

# Pull images
forEach "pull" "${PULL_IMAGES[@]}"

# Build docker image used by the client
# that actually tunnels the traffic.
INFO "Building docker image for ssh tunnel..."
IMAGE_SSHTUNNEL=$(docker build -q - <<EOF
FROM alpine
RUN apk add autossh
EOF
)

# Build nginx proxy docker container.
INFO "Building docker image for nginx proxy..."
IMAGE_PROXY=$(docker build -q .)

function traps {
  cleanup
}

# set trap
trap traps 0

# create network and volume
docker network create ${NETWORK_NAME}
docker volume create ${VOLUME_NAME}

RED=$(echo -e '\033[0;31m')
BLUE=$(echo -e '\033[0;34m')
GREEN=$(echo -e '\033[0;32m')
YELLOW=$(echo -e '\033[0;33m')
PURPLE=$(echo -e '\033[0;35m')
NC=$(echo -e '\033[0m')

WILDCARD_HOST="*.${CONT_PROXY}"
REQUEST_HOST="test.${CONT_PROXY}"

echo "Creating proxy container..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume="${VOLUME_NAME}:/certs/live/${WILDCARD_HOST}" \
  -e SERVER="${WILDCARD_HOST}" \
  -e SUBJECT="${WILDCARD_HOST}" \
  -e ALTNAME="${REQUEST_HOST}" \
  --network-alias="${REQUEST_HOST}" \
  -e TUNNEL_HOST=${CONT_SSHSERVER} \
  -e TUNNEL_PORT=5000 \
  --name=${CONT_PROXY} \
  "${IMAGE_PROXY}" 2>&1 | sed "s/.*/$GREEN&$NC/" &

echo "Generating ssh keys..."
docker run --rm \
  --volume=${VOLUME_NAME}:/ssh_keys \
  --name=${CONT_SSHKEYGEN} \
  "${IMAGE_SSHTUNNEL}" \
  ssh-keygen -q -N "" -f /ssh_keys/id_rsa

echo "Running ssh server..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/ssh_keys \
  -e PUBLIC_KEY_FILE=/ssh_keys/id_rsa.pub \
  -e USER_NAME=dev \
  -e DOCKER_MODS=linuxserver/mods:openssh-server-ssh-tunnel \
  -p 5000 \
  --name=${CONT_SSHSERVER} \
  linuxserver/openssh-server:9.0_p1-r2-ls94 2>&1 | sed "s/.*/$RED&$NC/" &

echo "Creating destination container..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --name=${CONT_DESTINATION} \
  quay.io/k8start/http-headers:1.0.0 \
  \
  --port=9000 2>&1 | sed "s/.*/$YELLOW&$NC/" &

sleep 5
echo "Running ssh tunnel..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/ssh_keys \
  --name=${CONT_SSHTUNNEL} \
  "${IMAGE_SSHTUNNEL}" \
    autossh -M 0 -N -o StrictHostKeyChecking=no \
    -i /ssh_keys/id_rsa -p 2222 \
    -R 0.0.0.0:5000:${CONT_DESTINATION}:9000 dev@${CONT_SSHSERVER} 2>&1 | sed "s/.*/$BLUE&$NC/" &

sleep 10
echo "Running client waiting to be tunneled..."
RESULT=$(docker run --rm \
  --network=${NETWORK_NAME} \
  --volume="${VOLUME_NAME}:/certs/live/${WILDCARD_HOST}" \
  --name=${CONT_CLIENT} \
  curlimages/curl \
  \
  curl:7.85.0 --fail-with-body -v -L \
  -H 'User-Agent:' -H 'Header1: header1' -H 'Header2: header2'\
  "${REQUEST_HOST}" \
    --cacert /certs/live/*.${CONT_PROXY}/fullchain.pem)

WANT="Instance name: example
Accept: [*/*]
Connection: [close]
Header1: [header1]
Header2: [header2]
Host: [$REQUEST_HOST]"

printf "===\nResult:\n===\n$RESULT\n"; printf "===\nWant:\n===\n$WANT\n===\n";

if [[ "$RESULT" != "$WANT" ]]; then
  printf "test failed"; exit 1
  else
    echo "test passed"
fi
