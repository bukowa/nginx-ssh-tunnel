#!/bin/bash

function inspect {
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
      return 1
    fi
}

function build {
  docker build -t ${OPENSSH_TAG} -f - . 1>/dev/null "<<EOF
  FROM alpine
  RUN apk add openssh autossh
  EXPOSE 5000
  EOF"
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
