class contrail::collector (
) inherits ::contrail::params {

    # If internal VIP is configured, use that address as config_ip.
    # Main code for class
    case $::operatingsystem {
	'Ubuntu': {
	      file {"/etc/init/supervisor-analytics.override": ensure => absent, require => Package['contrail-openstack-analytics']}
	      file { '/etc/init.d/supervisor-analytics':
		       ensure => link,
		 target => '/lib/init/upstart-job',
		 before => Service["supervisor-analytics"]
	      }


	}
    }

    if $multi_tenancy == true {
        $memcached_opt = "memcache_servers=127.0.0.1:11211"
    }
    else {
        $memcached_opt = ""
    }

    if ! defined(File["/etc/contrail/contrail-keystone-auth.conf"]) {
        file { "/etc/contrail/contrail-keystone-auth.conf" :
            ensure  => present,
            require => Package["contrail-openstack-analytics"],
            notify =>  Service["supervisor-analytics"],
            content => template("$module_name/contrail-keystone-auth.conf.erb"),
        }
    }

    # Ensure all needed packages are present
    package { 'contrail-openstack-analytics' : ensure => latest, notify => "Service[supervisor-analytics]"}
    ->
    # The above wrapper package should be broken down to the below packages
    # For Debian/Ubuntu - supervisor, python-contrail, contrail-analytics, contrail-setup, contrail-nodemgr
    # For Centos/Fedora - contrail-api-pib, contrail-analytics, contrail-setup, contrail-nodemgr

    # Ensure all config files with correct content are present.
    file { "/etc/contrail/contrail-analytics-api.conf" :
	ensure  => present,
	require => Package["contrail-openstack-analytics"],
	content => template("$module_name/contrail-analytics-api.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-collector.conf" :
	ensure  => present,
	require => Package["contrail-openstack-analytics"],
	content => template("$module_name/contrail-collector.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-query-engine.conf" :
	ensure  => present,
	require => Package["contrail-openstack-analytics"],
	content => template("$module_name/contrail-query-engine.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-snmp-collector.conf" :
        ensure  => present,
        require => [Package["contrail-openstack-analytics"],
                    File["/etc/contrail/contrail-keystone-auth.conf"]
                   ],
        content => template("$module_name/contrail-snmp-collector.conf.erb")
    }
    ->
    file { "/etc/contrail/supervisord_analytics_files/contrail-snmp-collector.ini" :
        ensure  => present,
        require => Package["contrail-openstack-analytics"],
        content => template("$module_name/contrail-snmp-collector.ini.erb"),
    }
    ->
    exec { "setsnmpmib":
        command => "mkdir -p /etc/snmp && echo 'mibs +ALL' > /etc/snmp/snmp.conf",
        require => Package["contrail-openstack-analytics"],
        provider => shell,
        logoutput => $contrail_logoutput
    }
    ->
    file { "/etc/contrail/vnc_api_lib.ini" :
        ensure  => present,
        content => template("$module_name/vnc_api_lib.ini.erb"),
    }
    ->
    file { "/etc/contrail/contrail-analytics-nodemgr.conf" :
        ensure  => present,
        require => Package["contrail-openstack-analytics"],
        content => template("$module_name/contrail-analytics-nodemgr.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-topology.conf" :
        ensure  => present,
        require => Package["contrail-openstack-analytics"],
        content => template("$module_name/contrail-topology.conf.erb"),
    }
    ->
    file { "/etc/redis/redis.conf" :
        ensure  => present,
        require => Package["contrail-openstack-analytics"],
        content => template("$module_name/redis.conf.erb"),
    }
    ->
    exec { "redis-del-db-dir":
	command => "rm -f /var/lib/redis/dump.rb && service redis-server restart && echo redis-del-db-dir etc/contrail/contrail-collector-exec.out",
	require => Package["contrail-openstack-analytics"],
	unless  => "grep -qx redis-del-db-dir /etc/contrail/contrail-collector-exec.out",
	provider => shell,
	logoutput => $contrail_logoutput
    }
    ->
    # Ensure the services needed are running.
    service { "supervisor-analytics" :
	enable => true,
	require => [ Package['contrail-openstack-analytics']
		   ],
	subscribe => [ File['/etc/contrail/contrail-collector.conf'],
		       File['/etc/contrail/contrail-query-engine.conf'],
		       File['/etc/contrail/contrail-analytics-api.conf'] ],
	ensure => running,
    }
     $registered_haproxy.each |$index, $val| {
     notify { "hanode: $val.$domain":; }
     exec { "kick haproxy update $val":
       command => "puppet kick $val.$domain",
       path    => "/usr/bin/:/bin/",
     }
  }

}
