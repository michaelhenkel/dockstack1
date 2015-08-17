docker inspect --format "{{ .State.Pid }}" galera
pid=$(sudo docker inspect --format "{{ .State.Pid }}" galera)
ln -s /proc/$pid/ns/net /var/run/netns/galera
ip link add gal-eth0 type veth peer name gal-eth1
ip link set gal-eth1 netns galera
ovs-vsctl add-port br0 gal-eth0
ip netns exec galera ip link set dev gal-eth1 up
ip netns exec galera dhclient gal-eth1
