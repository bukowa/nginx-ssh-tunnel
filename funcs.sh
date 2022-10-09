#!/bin/bash

function isInspectable {
    err=()
    arr=("$@")
    for i in "${arr[@]}"
    do
      INFO "Inspecting resource: $i..."
      if docker inspect "$i" &> /dev/null;
      then
          INFO "Resource: $i exists..."
          err+=("$i")
      fi
    done
    if [ "${#err[@]}" -gt 0 ];
    then
      INFO "Resources: ${err[*]} exists..."
      return 0
    fi
    return 1
}

function ERROR {
    echo "ERROR: $1"
}

function WARN {
  echo "WARNING: $1"
}

function INFO {
    echo "INFO: $1"
}

function FATAL {
    echo "FATAL: $1"
    exit 1
}

#
#
## 1
#printf "${DOCKERFILE}" | docker build -t ${OPENSSH_TAG} -f - . 1>/dev/null
#
## 2
#docker build -t ${OPENSSH_TAG} -f - . 1>/dev/null <<EOF
#$(cat Dockerfile)
#EOF
#
## 3
#cat Dockerfile | docker build -t ${OPENSSH_TAG} -f - . 1>/dev/null
#
## 4
#docker build -t ${OPENSSH_TAG} -f - . 1>/dev/null <<EOF
#FROM alpine
#RUN apk add autossh
#EXPOSE 5000
#EOF
