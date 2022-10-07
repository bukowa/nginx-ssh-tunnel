#!/bin/bash
set -e

# docker image
IMAGE_TAG=testsshtunnel

# docker related stuff
PROXY_NAME="just_a_proxy"
CLIENT_NAME="just_a_client"
DEST_NAME="just_a_destination"
NETWORK_NAME="just_a_proxy_client_network"
VOLUME_NAME="just_a_proxy_client_volume"

# container config
SERVER=${PROXY_NAME}

# build docker image
docker build --tag=${IMAGE_TAG} .

# if any of these exists - exit
echo "Checking if we can run..."
if docker inspect ${PROXY_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${CLIENT_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${DEST_NAME}; then echo "this is bad"; exit 1; fi
if docker network inspect ${NETWORK_NAME}; then echo "this is bad"; exit 1; fi
if docker volume inspect ${VOLUME_NAME}; then echo "this is bad"; exit 1; fi
echo "We can run...!"

# remove all resources created in this script
function cleanup() {
  set +e
  echo "Cleaning up..."
  docker rm -f ${PROXY_NAME}
  docker rm -f ${CLIENT_NAME}
  docker rm -f ${DEST_NAME}
  docker network remove ${NETWORK_NAME}
  docker volume remove ${VOLUME_NAME}
  echo "Cleaned up..."
}

# set trap
trap cleanup 0

# create network and volume
docker network create ${NETWORK_NAME}
docker volume create ${VOLUME_NAME}

# create container proxy
docker run --rm \
  --network=${NETWORK_NAME} \
  -e SERVER=${PROXY_NAME} \
  -e TUNNEL_HOST=${DEST_NAME} \
  --volume=${VOLUME_NAME}:/certs/live/${SERVER} \
  -d \
  --name=${PROXY_NAME} \
  ${IMAGE_TAG}

# create container destination
docker run --rm \
  --network=${NETWORK_NAME} \
  -d \
  --name=${DEST_NAME} \
  quay.io/k8start/http-headers:0.1.1 \
    --port=5055

# test with container client
docker run --rm \
  --network=${NETWORK_NAME} \
  --volume=${VOLUME_NAME}:/certs/live/${SERVER} \
  --name=${CLIENT_NAME} \
  curlimages/curl \
  \
  curl -L ${PROXY_NAME} \
    --cacert /certs/live/${SERVER}/fullchain.pem \
  || echo "Test failed..."; exit 1
