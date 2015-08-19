Dockstack

Dockstack is a proof-of-concept on running OpenStack and OpenContrail as application containers using Docker as the container management layer.
The motiviation is to build an easy-to-install and scalable OpenStack/OpenContrail environment.
Different software components are grouped together as an application container based on scalability requirements:

Application containers:

1. dnsmasq:
 - manages DNS and DHCP for all following containers

2. puppet:
 - provisions configuration into all following containers

3. haproxy/keepalived:
 - provides application loadbalancing and VRRP to all following containers

4. galera:
 - MariaDB Galera database used by the OpenStack container

5. openstack:
 - horizon, nova-api, neutron-server, cinder, glance, keystone, rabbitmq

6. cassandra:
 - nosql database used by Contrail, includes zookeeper and kafka

7. config:
 - Contrail config, ifmap and discovery

8. collector:
 - Contrail analytics

9. control:
 - Contrail controller 

10. webui:
 - Contrail webui
