#!/bin/bash
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

RESOURCES=(
  "${CONT_CLIENT}" "${CONT_DESTINATION}" "${CONT_PROXY}"
  "${CONT_SSHKEYGEN}" "${CONT_SSHSERVER}" "${CONT_SSHTUNNEL}"
  "${NETWORK_NAME}" "${VOLUME_NAME}"
)

# If any of these resources exists, quit.
if ! inspect "${RESOURCES[@]}"; then FATAL "Some resources exist"; fi

#docker build --tag=${IMAGE_TAG} .
docker build -t ${OPENSSH_TAG} -f - . 1>/dev/null <<EOF
FROM alpine
RUN apk add openssh autossh
EXPOSE 5000
EOF

echo "here"
exit 1

# container config
SERVER=${CONT_PROXY}

# # pull all images
# docker pull linuxserver/openssh-server
# docker pull linuxserver/mods:openssh-server-ssh-tunnel
# docker pull quay.io/k8start/http-headers:0.1.1
# docker pull curlimages/curl
#
#Using default tag: latest
#latest: Pulling from linuxserver/openssh-server
#Digest: sha256:56df195fc1cf8db0aaf2108fc1d0f276843e70261c6fca598789fff2faddcce0
#Status: Image is up to date for linuxserver/openssh-server:latest
#docker.io/linuxserver/openssh-server:latest
#openssh-server-ssh-tunnel: Pulling from linuxserver/mods
#Digest: sha256:2890aea04dc9255c71ce533ba69f89302c0f739783f9ec0f3f2faf9adb30cf0c
#Status: Image is up to date for linuxserver/mods:openssh-server-ssh-tunnel
#docker.io/linuxserver/mods:openssh-server-ssh-tunnel
#0.1.1: Pulling from k8start/http-headers
#Digest: sha256:c453cf1dedd927dc6b94879f79661c2e436552ff8e7bffe7104ea1176c530fbb
#Status: Image is up to date for quay.io/k8start/http-headers:0.1.1
#quay.io/k8start/http-headers:0.1.1
#Using default tag: latest
#latest: Pulling from curlimages/curl
#Digest: sha256:9fab1b73f45e06df9506d947616062d7e8319009257d3a05d970b0de80a41ec5
#Status: Image is up to date for curlimages/curl:latest
#docker.io/curlimages/curl:latest

# build docker images
# docker build --tag=${IMAGE_TAG} .
# docker build -t ${OPENSSH_TAG} -f - . <<EOF
# FROM alpine
# RUN apk add openssh autossh
# EXPOSE 5000
# EOF
source funcs.sh

inspect ${CONT_PROXY} ${CONT_CLIENT}
exit 1

# if any of these exists - exit
echo "Checking if we can run..."
if docker inspect ${CONT_PROXY}; then echo "this is bad"; exit 1; fi
if docker inspect ${CONT_CLIENT}; then echo "this is bad"; exit 1; fi
if docker inspect ${CONT_DESTINATION}; then echo "this is bad"; exit 1; fi
if docker inspect ${CONT_SSHTUNNEL}; then echo "this is bad"; exit 1; fi
if docker inspect ${CONT_SSHSERVER}; then echo "this is bad"; exit 1; fi
if docker inspect ${CONT_SSHKEYGEN}; then echo "this is bad"; exit 1; fi
if docker network inspect ${NETWORK_NAME}; then echo "this is bad"; exit 1; fi
if docker volume inspect ${VOLUME_NAME}; then echo "this is bad"; exit 1; fi
echo "We can run...!"

# remove all resources created in this script
function cleanup() {
  echo "Trapped... last exit code: $?"
  set +e
  echo "Cleaning up..."
  docker rm -f ${CONT_PROXY}
  docker rm -f ${CONT_CLIENT}
  docker rm -f ${CONT_DESTINATION}
  docker rm -f ${CONT_SSHKEYGEN}
  docker rm -f ${CONT_SSHTUNNEL}
  docker rm -f ${CONT_SSHSERVER}
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
  --name=${CONT_SSHKEYGEN} \
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
