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

The OpenStack compontens can be broken down into separate application containers but for this PoC it's just fine to have them all in one.
A client (dockstack-client) and server (dockstack-server) component is used to manage the live cycle of the application containers. Based on the configuration file the application
container can be created, removed, started and stopped on different Docker hosts.
In the standard Docker setup IP addresses are not persistent, i.e. everytime a container is stopped and restarted or removed and recreated the IP address
changes. In order to maintain IP address dnsmasq is used. Each container (besides the dnsmasq container itself) receives its IP address from the dnsmasq
container and generates a DNS entry.

               +---------------------------+               
               |has container static MAC/IP|               
               |in config file?            +----------+    
               +---------------------------+          |    
                            |No                       |    
                  +----------------------+        Yes |    
                  | is container name in |            |    
               +--+ dhcp lease file?     +--+         |    
               |  +----------------------+  |         |    
            No |                            | Yes     |    
    +----------+------------+            +--+---------+-------+
    |start container without|            |start container with|
    |MAC address            |            |assigned MAC address|
    +----------+------------+            +-----+--------------+
               |                               |           
               |                   +-----------+--------+  
               |            No     | static IP in config|  
               |         +---------+ file?     |        |  
               |         |         +--------------------+  
               |         |                     | Yes       
        +------+---------+--+       +----------+--------+  
        |run dhclient inside|       |configure static IP|  
        |container          |       +----------+--------+  
        +------+------------+                  |           
               |                               |           
         +-----+-----------+                   |           
         |retrieve assigned|                   |           
         |IP and MAC       |                   |           
         +-----+-----------+                   |           
               |                               |           
               |     +---------------+         |           
               |     |update dns/dhcp|         |           
               +-----+file and reload<---------+           
                     |dnsmasq        |                     
                     +---------------+                     


Instead of using Dockers virtual switching stack (Linux bridge) OpenVswitch is used. The dockstack-server creates network namespaces per container
and links a it to an OVS bridge. All namespace operations are performed using the pyroute2 library.
Communication between two Docker hosts can be done by linking the OVS of the hosts through VxLAN:

    +-------------------------------------------+ +-------------------------------------------+
    |              Docker Host 1                | |               Docker Host 2               |
    |                                           | |                                           |
    | +-----------+ +-----------+ +-----------+ | | +-----------+ +-----------+ +-----------+ |
    | | Container | | Container | | Container | | | | Container | | Container | | Container | |
    | |    1      | |    2      | |    3      | | | |    4      | |    5      | |    N      | |
    | +-----------+ +-----------+ +-----------+ | | +-----------+ +-----------+ +-----------+ |
    | | Namespace | | Namespace | | Namspace  | | | | Namespace | | Namespace | | Namespace | |
    | |    1      | |    2      | |    3      | | | |    4      | |    5      | |    N      | |
    | | +------+  | | +------+  | | +------+  | | | | +------+  | | +------+  | | +------+  | |
    | | | eth0 |  | | | eth0 |  | | | eth0 |  | | | | | eth0 |  | | | eth0 |  | | | eth0 |  | |
    | +-+--+---+--+ +-+--+---+--+ +-+--+---+--+ | | +-+--+---+--+ +-+--+---+--+ +-+--+---+--+ |
    |      |             |             |        | |      |             |             |        |
    | +----+---+---------+---+---------+---+--+ | | +----+---+---------+---+---------+---+--+ |
    | | |1eth1 |      |2eth1 |      |3eth1 |  | | | | |4eth1 |      |5eth1 |      |6eth1 |  | |
    | | +------+      +------+      +------+  | | | | +------+      +------+      +------+  | |
    | |                                       | | | |                                       | |
    | | OVS br0      +------+                 | | | |               -------+        OVC br0 | |
    | |              |VxLAN1+---------------------------------------+VXLAN2|                | |
    | |              |      |                 | | | |               |      |                | |
    | +--------------+------+-----------------+ | | +---------------+------+----------------+ |
    |                                           | |                                           |
    |                +------+                   | |                 +------+                  |
    |                | eth0 |                   | |                 | eth0 |                  |
    +----------------+-+----+-------------------+ +-----------------+---+--+------------------+
                       |                                                |                      
                       +------------------------------------------------+                      

