#!/bin/bash
set -e

IMAGE_TAG=testsshtunnel
SERVER=localhost

PROXY_NAME="just_a_proxy"
CLIENT_NAME="just_a_client"
NETWORK_NAME="just_a_proxy_client_network"
VOLUME_NAME="just_a_proxy_client_volume"

# build docker image
docker build --tag=${IMAGE_TAG} .

# if any of these exists - exit
echo "Checking if we can run..."
if docker inspect ${PROXY_NAME}; then echo "this is bad"; exit 1; fi
if docker inspect ${CLIENT_NAME}; then echo "this is bad"; exit 1; fi
if docker network inspect ${NETWORK_NAME}; then echo "this is bad"; exit 1; fi
if docker volume inspect ${VOLUME_NAME}; then echo "this is bad"; exit 1; fi
echo "We can run...!"

# remove all resources created in this script
function cleanup() {
  set +e
  echo "Cleaning up..."
  docker rm -f ${PROXY_NAME}
  docker rm -f ${CLIENT_NAME}
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
  --network=${IMAGE_TAG} \
  --name=${PROXY_NAME} \
  -e SERVER=${SERVER} \
  --volume=${VOLUME_NAME}:/certs/live/${SERVER} \
  -d \
  ${IMAGE_TAG}

# test with container client
docker run --rm \
  --network=${IMAGE_TAG} \
  --name=${CLIENT_NAME} \
  curlimages/curl \
  curl -L ${PROXY_NAME} || echo "Test failed..."; exit 1
