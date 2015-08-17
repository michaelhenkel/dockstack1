#!/bin/bash

DHCP_FILE=/etc/dnsmasq.conf
DNS_FILE=/etc/dnsmasq.d/docker/dns/docker-dns-file
CONTAINER_DOMAIN=endor.lab

MAC=`docker inspect --format '{{ .NetworkSettings.MacAddress }}' $1`
IP=`docker inspect --format '{{ .NetworkSettings.IPAddress }}' $1`
NAME=`docker inspect --format '{{ .Config.Hostname }}' $1`
grep $NAME.$CONTAINER_DOMAIN $DNS_FILE
if [[ $? -eq 0 ]]; then
   sed -i "s/.*$NAME.$CONTAINER_DOMAIN.*/$IP  $NAME.$CONTAINER_DOMAIN/" $DNS_FILE
else
  echo "$IP  $NAME.$CONTAINER_DOMAIN" >> $DNS_FILE
fi
echo "dhcp-host=$MAC,$NAME,$IP,infinite" >> $DHCP_FILE
pkill -x -HUP dnsmasq
