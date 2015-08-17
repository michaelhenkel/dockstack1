class mymod::ha (
) inherits mymod::params {
  $auth_string = join(["auth  ",$haproxy_user,":",$haproxy_password],'')
  class { 'haproxy':
       global_options   => {
          'log'           => "127.0.0.1 local2",
          'chroot'        => '/var/lib/haproxy',
          'pidfile'       => '/var/run/haproxy.pid',
          'maxconn'       => '4000',
          'user'          => 'haproxy',
          'group'         => 'haproxy',
          'daemon'        => '',
    	   stats       => [
                'socket /var/lib/haproxy/stats mode 600 level admin',
           ]
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
    	   stats       => [
        	'enable',
        	'show-legends',
        	'refresh 5s',
        	'uri /',
        	'realm Haproxy\ Statistics',
        	$auth_string,
		#'stats timeout 2m'
        	#'admin if TRUE',
    	  ]
      },
      restart_command => 'killall haproxy && service haproxy start',
  }
  haproxy::listen { 'haproxy-monitoring':
    mode 	=> 'http',
    ipaddress	=> '0.0.0.0',
    ports	=> '8080',
  }

if (size($registered_galera) > 0 ){
  haproxy::listen { 'galera':
    mode 	=> 'tcp',
    ipaddress	=> '0.0.0.0',
    ports	=> '3306',
    options	=> [
        {'option' 	=> [
        	'tcpka',
        	'nolinger',
        ],
        'balance'	=> 'source',},
    ]
  }  
  
  $registered_galera.each |$index, $val| { if($index== 0) {  
    haproxy::balancermember { $val:
      listening_service => 'galera',
      server_names      => $val,
      ipaddresses       => $val,
      ports             => '3306',
      options           => [
          'check',
          'weight 200',
          'inter 2000',
          'rise 2',
          'fall 3',
      ]
    }
  }else{
      haproxy::balancermember { $val:
      listening_service => 'galera',
      server_names      => $val,
      ipaddresses       => $val,
      ports             => '3306',
      options           => [
          'check',
          'weight 200',
          'inter 2000',
          'rise 2',
          'fall 3',
          'backup',
      ]
    }
  } 
 }
}

if (size($registered_openstack) > 0 ){
  haproxy::listen { 'keystone-int':
    ipaddress	=> '0.0.0.0',
    ports	=> '35357',
    options	=> [
        {'option' 	=> [
        	'tcpka',
        	'httpchk',
        	'tcplog',
           ],
        'balance'	=> 'roundrobin',
        },
    ]
  }

  haproxy::listen { 'keystone-ext':
    ipaddress   => '0.0.0.0',
    ports       => '5000',
    options	=> {
        'option' 	=> [
        	'tcpka',
        	'httpchk',
        	'tcplog',
        ],
        'balance'	=> 'roundrobin',
    },
  }
 
  haproxy::listen { 'glance-api':
    ipaddress   => '0.0.0.0',
    ports       => '9292',
    options     => {
        'option'        => [
                'tcpka',
                'httpchk',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'glance-registry':
    ipaddress   => '0.0.0.0',
    ports       => '9191',
    options     => {
        'option'        => [
                'tcpka',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'rabbitmq':
    mode        => 'tcp',
    ipaddress   => '0.0.0.0',
    ports       => '5672',
    options     => {
        'option'        => [
                'tcpka',
                'nolinger',
        ],
        'balance'       => 'leastconn',
    },
  }

  haproxy::listen { 'nova-api':
    ipaddress   => '0.0.0.0',
    ports       => '8773',
    options     => {
        'option'        => [
                'tcpka',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'nova-metadata':
    ipaddress   => '0.0.0.0',
    ports       => '8775',
    options     => {
        'option'        => [
                'tcpka',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'nova-compute-api':
    ipaddress   => '0.0.0.0',
    ports       => '8774',
    options     => {
        'option'        => [
                'tcpka',
                'httpchk',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'neutron-api':
    ipaddress   => '0.0.0.0',
    ports       => '9696',
    options     => {
        'option'        => [
                'tcpka',
                'httpchk',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'cinder-api':
    ipaddress   => '0.0.0.0',
    ports       => '8776',
    options     => {
        'option'        => [
                'tcpka',
                'httpchk',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'dashboard':
    ipaddress   => '0.0.0.0',
    ports       => '80',
    options     => {
        'option'        => [
                'tcpka',
                'httpchk',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::balancermember { 'keystone-int':
    listening_service => 'keystone-int',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '35357',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'keystone-ext':
    listening_service => 'keystone-ext',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '5000',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'glance-api':
    listening_service => 'glance-api',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '9292',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'glance-registry':
    listening_service => 'glance-registry',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '9191',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'rabbitmq':
    listening_service => 'rabbitmq',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '5672',
    options           => [
          'weight 200',
          'check',
          'inter 2000',
          'rise 2',
          'fall 3',
      ]
  }

  haproxy::balancermember { 'nova-api':
    listening_service => 'nova-api',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '8773',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'nova-metadata':
    listening_service => 'nova-metadata',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '8775',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'nova-compute-api':
    listening_service => 'nova-compute-api',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '8774',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'neutron-api':
    listening_service => 'neutron-api',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '9696',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'cinder-api':
    listening_service => 'cinder-api',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '8776',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'dashboard':
    listening_service => 'dashboard',
    server_names      => $registered_openstack,
    ipaddresses       => $registered_openstack,
    ports             => '80',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }
}


if (size($registered_config) > 0 ){
  haproxy::listen { 'ifmap':
    mode        => 'tcp',
    ipaddress   => '0.0.0.0',
    ports       => '8443',
    options     => {
        'option'        => [
                'tcpka',
                'nolinger',
        ],
        'balance'       => 'leastconn',
    },
  }

  haproxy::balancermember { 'ifmap':
    listening_service => 'ifmap',
    server_names      => $registered_config,
    ipaddresses       => $registered_config,
    ports             => '8443',
    options           => [
          'weight 200',
          'check',
          'inter 2000',
          'rise 2',
          'fall 3',
      ]
  }

  haproxy::listen { 'discover':
    ipaddress   => '0.0.0.0',
    ports       => '5998',
    options     => {
        'option'        => [
                'nolinger',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::listen { 'contrail-api':
    ipaddress   => '0.0.0.0',
    ports       => '8082',
    options     => {
        'option'        => [
                'nolinger',
        ],
        'balance'       => 'roundrobin',
    },
  }
 
  haproxy::balancermember { 'discover':
    listening_service => 'discover',
    server_names      => $registered_config,
    ipaddresses       => $registered_config,
    ports             => '9110',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

  haproxy::balancermember { 'contrail-api':
    listening_service => 'contrail-api',
    server_names      => $registered_config,
    ipaddresses       => $registered_config,
    ports             => '9100',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }
}


if (size($registered_collector) > 0 ){

  haproxy::listen { 'collector':
    ipaddress   => '0.0.0.0',
    ports       => '9081',
    options     => {
        'option'        => [
                'nolinger',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::balancermember { 'collector':
    listening_service => 'collector',
    server_names      => $registered_collector,
    ipaddresses       => $registered_collector,
    ports             => '9081',
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }

}
if (size($registered_webui) > 0 ){
  haproxy::listen { 'webui':
    ipaddress   => '0.0.0.0',
    ports       => [ '8081', '8143' ],
    options     => {
        'option'        => [
                'tcpka',
                'tcplog',
        ],
        'balance'       => 'roundrobin',
    },
  }

  haproxy::balancermember { 'webui':
    listening_service => 'webui',
    server_names      => $registered_webui,
    ipaddresses       => $registered_webui,
    ports             => ['8080','8143'],
    options           => [
          'check',
          'inter 2000',
          'rise 2',
          'fall 5',
      ]
  }
}
}

