class mymod::ka (
) inherits mymod::params {
  class { 'keepalived::global_defs':
    ensure                  => present,
    router_id               => $::hostname,
  }
  include ::keepalived
  $hostname = $::hostname
  notify { "reg ha: $registered_haproxy":; }
  $ha_index = inline_template('<%= @registered_haproxy.index(@hostname) %>')
  notify { "index: $ha_index":; }
  if($ha_index == '0') {  
      $state = 'MASTER'
  }
  $priority = 100 + $ha_index
  keepalived::vrrp::script { 'check_haproxy_vip':
    script => '/usr/bin/killall -0 haproxy',
    interval => '1',
    weight => '1',
    timeout => '3',
    fall => '2',
    rise => '2',
  }
  keepalived::vrrp::instance { 'VI_50':
    interface         => 'eth0',
    state             => $state,
    virtual_router_id => '50',
    priority          => $priority,
    auth_type         => 'PASS',
    auth_pass         => 'secret',
    net_mask           => $vip_mask,
    virtual_ipaddress => [ $vip ],
    track_interface   => ['eth0'], # optional, monitor these interfaces.
    track_script      => ['check_haproxy_vip']
  }
}
