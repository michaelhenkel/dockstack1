class mymod::ha (
       $auth_string = join(["auth  ",$ha_user,":",$ha_pwd],'')
) inherits mymod::params {
  $vip 				= hiera('common::vip','')
  $vip_mask 			= hiera('common::vip_mask','')
  $vip_name 			= hiera('common::vip_name','')
  $domain 			= hiera('common::domain','')
  $galera_nodes 		= hiera('common::galera_nodes','')
  $openstack_nodes 		= hiera('common::openstack_nodes','')
  $cassandra_nodes 		= hiera('common::cassandra_nodes','')
  $config_nodes 		= hiera('common::config_nodes','')
  $control_nodes 		= hiera('common::control_nodes','')
  $collector_nodes 		= hiera('common::collector_nodes','')
  $webui_nodes 			= hiera('common::webui_nodes','')
  $keystone_admin_user 		= hiera('common::keystone_admin_user','')
  $keystone_admin_tenant 	= hiera('common::keystone_admin_tenant','')
  $keystone_admin_password 	= hiera('common::keystone_admin_password','')
  $haproxy_user 		= hiera('haproxy::user','')
  $haproxy_password 		= hiera('haproxy::password','')
  $test 			= hiera("common2")
  $test2 = $test['test']
  notify { "blabla: $test2":; }
  class { 'haproxy':
       global_options   => {
          'log'           => "127.0.0.1 local2",
          'chroot'        => '/var/lib/haproxy',
          'pidfile'       => '/var/run/haproxy.pid',
          'maxconn'       => '4000',
          'user'          => 'haproxy',
          'group'         => 'haproxy',
          'daemon'        => '',
    	  'stats'         => 'socket /var/lib/haproxy/stats mode 600 level admin',
       },
       defaults_options => {
	  'source'  => $vip,
          'log'     => 'global',
          'stats'   => 'enable',
          'option'  => 'redispatch',
          'retries' => '3',
          'timeout' => [
                  'http-request 20min',
                  'queue 1m',
                  'connect 20min',
                  'client 20min',
                  'server 20min',
                  'check 10s',
          ],
          'maxconn' => '8000',
      },
      #restart_command => 'killall haproxy && service haproxy start',
  }

  haproxy::frontend { 'haproxy-frontend':
    default_backend 	=> 'haproxy-backend',
    mode 		=> 'http',
    ipaddress		=> '0.0.0.0',
    ports		=> '8080',
  }

  haproxy::backend { 'haproxy-backend':
    listening_service => 'haproxy-frontend',
    ports             => '8080',
    server_names      => ['${::hostname}'],
    ipaddresses       => ['${::ipaddress}'],
    options           => 'check',
  }

  haproxy::frontend { 'galera-frontend':
    default_backend 	=> 'galera-backend',
    mode        => 'tcp',
    ipaddress   => '0.0.0.0',
    ports       => '3306',
    options     => [
        {'option'       => [
                'tcpka',
                'nolinger',
        ],
        'balance'       => 'source',},
    ]
  }

  haproxy::backend { 'galera-backend':
    listening_service => 'galera-frontend',
    ports             => '3306',
    server_names      => $galera_nodes,
    ipaddresses       => $galera_nodes,
  }

}

