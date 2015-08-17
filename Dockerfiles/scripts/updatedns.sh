#!/bin/bash

CONTAINER_HOSTS=/etc/dnsmasq.d/docker-container-hosts
CONTAINER_DOMAIN=endor.lab

IP=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1`
NAME=`docker inspect --format '{{ .Config.Hostname }}' $1`
grep $NAME.$CONTAINER_DOMAIN $CONTAINER_HOSTS
if [[ $? -eq 0 ]]; then
   sed -i "s/.*$NAME.$CONTAINER_DOMAIN.*/$IP  $NAME.$CONTAINER_DOMAIN/" $CONTAINER_HOSTS
else
  echo "$IP  $NAME.$CONTAINER_DOMAIN" >> $CONTAINER_HOSTS
fi
pkill -x -HUP dnsmasq
