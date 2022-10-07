#!/bin/bash
set -e

# docker images
IMAGE_TAG=testsshtunnel
OPENSSH_TAG="openssh_sshtunnel"

# docker related stuff
PROXY_NAME="just_a_proxy"
CLIENT_NAME="just_a_client"
SSH_TUNNEL_NAME="just_a_ssh_tunnel"
SSH_SERVER_NAME="just_a_ssh_server"
SSH_GEN_NAME="just_a_ssh_gen_name"
DEST_NAME="just_a_destination"
NETWORK_NAME="just_a_proxy_client_network"
VOLUME_NAME="just_a_proxy_client_volume"

# container config
SERVER=${PROXY_NAME}

# build docker images
docker build --tag=${IMAGE_TAG} .
docker build -t ${OPENSSH_TAG} -f - . <<EOF
FROM alpine
RUN apk add openssh autossh
EXPOSE 5000
EOF

# if any of these exists - exit
echo "Checking if we can run..."
if docker inspect ${PROXY_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${CLIENT_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${DEST_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${SSH_TUNNEL_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${SSH_SERVER_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${SSH_GEN_NAME}; then echo "this is bad"; exit 1; fi
if docker network inspect ${NETWORK_NAME}; then echo "this is bad"; exit 1; fi
if docker volume inspect ${VOLUME_NAME}; then echo "this is bad"; exit 1; fi
echo "We can run...!"

# remove all resources created in this script
function cleanup() {
  echo "Trapped... last exit code: $?"
  set +e
  echo "Cleaning up..."
  docker rm -f ${PROXY_NAME}
  docker rm -f ${CLIENT_NAME}
  docker rm -f ${DEST_NAME}
  docker rm -f ${SSH_GEN_NAME}
  docker rm -f ${SSH_TUNNEL_NAME}
  docker rm -f ${SSH_SERVER_NAME}
  docker network remove ${NETWORK_NAME}
  docker volume remove ${VOLUME_NAME}
  echo "Cleaned up..."
}

# set trap
trap cleanup 0

# create network and volume
docker network create ${NETWORK_NAME}
docker volume create ${VOLUME_NAME}

echo "Generating ssh keys..."
docker run --rm \
  --volume=${VOLUME_NAME}:/ssh_keys \
  --name=${SSH_GEN_NAME} \
  ${OPENSSH_TAG} \
  ssh-keygen -q -N "" -f /ssh_keys/id_rsa &

echo "Running ssh server..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/ssh_keys \
  -e PUBLIC_KEY_FILE=/ssh_keys/id_rsa.pub \
  -e USER_NAME=dev \
  -e DOCKER_MODS=linuxserver/mods:openssh-server-ssh-tunnel \
  -p 5000 \
  --name=${SSH_SERVER_NAME} \
  linuxserver/openssh-server &

echo "Creating destination container..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --name=${DEST_NAME} \
  quay.io/k8start/http-headers:0.1.1 \
  \
  --port=9000 &

sleep 3
echo "Running ssh tunnel..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/ssh_keys \
  --name=${SSH_TUNNEL_NAME} \
  ${OPENSSH_TAG} \
    autossh -M 0 -N -o StrictHostKeyChecking=no \
    -i /ssh_keys/id_rsa -p 2222 \
    -R 0.0.0.0:5000:${DEST_NAME}:9000 dev@${SSH_SERVER_NAME} &

echo "Creating proxy container..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/certs/live/${SERVER} \
  -e SERVER=${PROXY_NAME} \
  -e TUNNEL_HOST=${SSH_SERVER_NAME} \
  -e TUNNEL_PORT=5000 \
  --name=${PROXY_NAME} \
  ${IMAGE_TAG} &

sleep 3
echo "Running client waiting to be tunneled..."
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/certs/live/${SERVER} \
  --name=${CLIENT_NAME} \
  curlimages/curl \
  \
  curl -v -L ${PROXY_NAME} \
    --cacert /certs/live/${SERVER}/fullchain.pem

echo "Looks like it works!"
