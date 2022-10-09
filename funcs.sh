#!/bin/bash

function inspect {
    err=()
    arr=("$@")
    for i in "${arr[@]}"
    do
      INFO "Inspecting resource: $i..."
      if docker inspect "$i" &> /dev/null;
      then
          WARN "Resource: $i exists..."
          err+=("$i")
      fi
    done
    if [ "${#err[@]}" -gt 0 ];
    then
      ERROR "Resources: ${err[*]} exists, quiting..."
      return 1
    fi
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
