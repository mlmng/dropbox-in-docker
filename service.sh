#!/bin/bash

: ${SERVICE:=" "}  #modify
: ${CPU:=100}
: ${MEMORY:=100M}
: ${DISK:=5G}

set -e -u

if ! test "$(whoami)" = 'root'; then
  echo 'this script must run as root.' >&2
  exit 1
fi
read -p "put your folder name..." SERVICE  #modify

DockerRun() {
  DOCKER_FLAGS+=(
      --volume="/storage/${SERVICE}:/home/cloud-admin"
      --memory="${MEMORY}" --cpu-shares="${CPU}"
  )
  docker run "${DOCKER_FLAGS[@]}" "${SERVICE}" "$@"
}

Mount() {  
  if ! mountpoint -q "/storage/${SERVICE}"; then
    if [ ! -f "/storage/${SERVICE}/image.dmg" ]; then
      echo "install docker-dropbox: './service.sh install'" >&2
      exit 1
    fi
    e2fsck -y -f "/storage/${SERVICE}/image.dmg"
    resize2fs "/storage/${SERVICE}/image.dmg" "${DISK}"
    mount -t auto -o loop "/storage/${SERVICE}/image.dmg" "/storage/${SERVICE}"
  fi
}

Start() {
  if docker top "${SERVICE}" >/dev/null 2>/dev/null; then
    echo 'docker is already running.' >&2
  fi
  Mount
  DOCKER_FLAGS=(--name="${SERVICE}" --hostname="${SERVICE}" --detach)
  DockerRun "$@"
}

Stop() {
  docker kill "${SERVICE}" >/dev/null || true
  docker rm "${SERVICE}" >/dev/null || true
  if mountpoint -q "/storage/${SERVICE}"; then
    fuser --kill "/storage/${SERVICE}" || true
    umount -f "/storage/${SERVICE}" || true
    if mountpoint -q "/storage/${SERVICE}"; then
      echo "failed to unmount: /storage/${SERVICE}" >&2
      exit 1
    fi
  fi
}

Install() {
  if mountpoint -q "/storage/${SERVICE}"; then
    echo "/storage/${SERVICE} is already mounted." >&2
  else
    if [ -f "/storage/${SERVICE}/image.dmg" ]; then
      echo "/storage/${SERVICE}/image.dmg already exists." >&2
    else
      mkdir -p "/storage/${SERVICE}"
      truncate --size="${DISK}" "/storage/${SERVICE}/image.dmg"
      yes | mkfs -t ext4 "/storage/${SERVICE}/image.dmg"
    fi
    Mount
  fi
  sed -i.org -e "s/--uid=20601/--uid=$ORGUID/" Dockerfile
  docker build --tag="${SERVICE}" .
  DOCKER_FLAGS=(--tty --interactive --rm)
  DockerRun /bin/bash /config/setup.sh
}

Uninstall() {
  Stop
  while true; do
    read -p "Do you really want to remove /storage/${SERVICE}? [yes/no] " yn
    if [ "${yn}" == 'yes' ]; then break; fi
    case "${yn}" in
      [Nn]*) exit;;
      *) echo "Please type 'Yes' or 'No'.";;
    esac
  done
  if mountpoint -q "/storage/${SERVICE}"; then
    umount -f "/storage/${SERVICE}"
  fi
  if [ -d "/storage/${SERVICE}" ]; then
    rm -rf "/storage/${SERVICE}"
  fi
}

command="$1"
shift
case "${command}" in
  'start') Start "$@";;
  'stop') Stop;;
  'install') Install;;
  'uninstall') Uninstall;;
  *) echo "no such command: ${command}" >&2;;
esac
