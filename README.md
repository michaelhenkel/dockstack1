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
A client (dockstack-client) and server (dockstack-server) component is used to manage the live cycle of the application containers. 
Based on the configuration file the application container can be created, removed, started and stopped on different Docker hosts.
The creation process is iniated by the dockstack-client and executed by the docker-server. Setup and configuration information are stored
in an environment file using the yaml data structure. The file contains generic and container specific information:

    common:
      dnsServer: 10.0.0.1
      domain: endor.lab
      galera_password: password
      haproxy_password: password
      haproxy_user: user
      keystone_admin_password: password
      keystone_admin_tenant: admin
      keystone_admin_token: token
      keystone_admin_user: admin
      puppetServer: puppet1
      vip: 10.0.0.254
      vip_mask: 16
      vip_name: vip
    registered_services:
      cassandra: []
      collector: []
      config: []
      control: []
      dns: []
      galera: []
      haproxy: []
      openstack: []
      puppet: []
      webui: []
    services:
      cassandra:
        cas1:
          host: 192.168.99.2
      collector:
        col1:
          host: 192.168.99.2
      config:
        conf1:
          host: 192.168.99.2
      control:
        ctrl1:
          host: 192.168.99.2
      dns:
        dns1:
          gateway: 10.0.0.100
          host: 192.168.99.2
          ipaddress: 10.0.0.1/16
          macAddress: de:ad:be:ef:ba:11
        dns2:
          gateway: 10.0.0.100
          host: 192.168.99.2
          ipaddress: 10.0.0.2/16
          macAddress: de:ad:be:ef:ba:12
      galera:
        gal1:
          host: 192.168.99.2
      haproxy:
        ha1:
          host: 192.168.99.2
        ha2:
          host: 192.168.99.2
      openstack:
        os1:
          host: 192.168.99.2
      puppet:
        puppet1:
          host: 192.168.99.2
        puppet2:
          host: 192.168.99.2
      webui:
        webui1:
          host: 192.168.99.2

The registered services section lists all running containers, the services section the different docker images with the container using the image 
and the docker host the container will run on. Optionally an IP address, a default GW and MAC address can be specified per container.
The name of the service must match the docker image name:

    #>docker images
    REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
    haproxy             latest              facdaa8d2030        9 days ago          295.9 MB
    dns                 latest              7466ef508541        9 days ago          261.3 MB
    puppet              latest              8dd0c5a0142a        9 days ago          382.1 MB
    webui               latest              c9125b2648a1        13 days ago         520.9 MB
    control             latest              dea0f627e0e3        13 days ago         525.5 MB
    collector           latest              c4239dc9d1b3        13 days ago         528.7 MB
    config              latest              abc5de63e7cd        13 days ago         703 MB
    cassandra           latest              02ddca950867        13 days ago         703.1 MB
    openstack           latest              cea138c40256        13 days ago         636.3 MB
    galera              latest              1db2424aaead        13 days ago         481.6 MB

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
and links it to an OVS bridge using a pair of veth interfaces. All namespace operations are performed using the pyroute2 library.
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
    | | OVS br0      +------+                 | | | |               -------+        OVS br0 | |
    | |              |VxLAN1+---------------------------------------+VXLAN2|                | |
    | |              |      |                 | | | |               |      |                | |
    | +--------------+------+-----------------+ | | +---------------+------+----------------+ |
    |                                           | |                                           |
    |                +------+                   | |                 +------+                  |
    |                | eth0 |                   | |                 | eth0 |                  |
    +----------------+-+----+-------------------+ +-----------------+---+--+------------------+
                       |                                                |                      
                       +------------------------------------------------+                      


