class contrail::config (
    $host_control_ip = $::ipaddress,
    $collector_ip = $::contrail::params::collector_ip_list[0],
    $database_ip_list = $::contrail::params::database_ip_list,
    $control_ip_list = $::contrail::params::control_ip_list,
    #$openstack_ip = $::contrail::params::openstack_ip_list[0],
    $uuid = $::contrail::params::uuid,
    $keystone_ip = $::contrail::params::keystone_ip,
    $keystone_admin_token = $::contrail::params::keystone_admin_token,
    $keystone_admin_user = $::contrail::params::keystone_admin_user,
    $keystone_admin_password = $::contrail::params::keystone_admin_password,
    $keystone_admin_tenant = $::contrail::params::keystone_admin_tenant,
    $keystone_service_token = $::contrail::params::keystone_service_token,
    $use_certs = $::contrail::params::use_certs,
    $multi_tenancy = $::contrail::params::multi_tenancy,
    $zookeeper_ip_list = $::contrail::params::zk_ip_list_to_use,
    $quantum_port = $::contrail::params::quantum_port,
    $quantum_service_protocol = $::contrail::params::quantum_service_protocol,
    $keystone_auth_protocol = $::contrail::params::keystone_auth_protocol,
    $keystone_auth_port = $::contrail::params::keystone_auth_port,
    $keystone_service_tenant = $::contrail::params::keystone_service_tenant,
    $keystone_insecure_flag = $::contrail::params::keystone_insecure_flag,
    $api_nworkers = $::contrail::params::api_nworkers,
    $haproxy = $::contrail::params::haproxy,
    $keystone_region_name = $::contrail::params::keystone_region_name,
    $manage_neutron = $::contrail::params::manage_neutron,
    $openstack_manage_amqp = $::contrail::params::openstack_manage_amqp,
    $amqp_server_ip = $::contrail::params::amqp_server_ip,
    #$openstack_mgmt_ip = $::contrail::params::openstack_mgmt_ip_list_to_use[0],
    $internal_vip = $::contrail::params::internal_vip,
    $external_vip = $::contrail::params::external_vip,
    $contrail_internal_vip = $::contrail::params::contrail_internal_vip,
    $contrail_plugin_location = $::contrail::params::contrail_plugin_location,
    $config_ip_list = $::contrail::params::config_ip_list,
    $config_name_list = $::contrail::params::config_name_list,
    $database_ip_port = $::contrail::params::database_ip_port,
    $zk_ip_port = $::contrail::params::zk_ip_port,
    $hc_interval = $::contrail::params::hc_interval,
    $vmware_ip = $::contrail::params::vmware_ip,
    $vmware_username = $::contrail::params::vmware_username,
    $vmware_password = $::contrail::params::vmware_password,
    $vmware_vswitch = $::contrail::params::vmware_vswitch,
    $config_ip = $::ipaddress,
    #$config_ip = $::contrail::params::vip_name,
    $collector_ip = $::contrail::params::collector_ip_to_use,
    $vip = $::contrail::params::vip_to_use,
    $contrail_rabbit_port= $::contrail::params::contrail_rabbit_port,
    $contrail_logoutput = $::contrail::params::contrail_logoutput,
) inherits ::contrail::params {
    notify { "reg cas $registered_cassandra":;}
    notify { "control_nodes $control_nodes":;}
    $control_node_list = keys($control_nodes)
    notify { "ishash $control_node_list":;}
   
     
    # Main code for class starts here
    if $use_certs == true {
	$ifmap_server_port = '8444'
    }
    else {
	$ifmap_server_port = '8443'
    }

    $analytics_api_port = '8081'
    $contrail_plugin_file = '/etc/neutron/plugins/opencontrail/ContrailPlugin.ini'
    $keystone_ip_to_use = $vip_name
    $amqp_server_ip_to_use = $internal_vipvip_name

    if $multi_tenancy == true {
	$memcached_opt = "memcache_servers=127.0.0.1:11211"
    }
    else {
	$memcached_opt = ""
    }
    # Initialize the multi tenancy option will update latter based on vns argument
    if ($multi_tenancy == true) {
	$mt_options = "admin,$keystone_admin_password,$keystone_admin_tenant"
    } else {
	$mt_options = "None"
    }

    # Supervisor contrail-api.ini
    $api_port_base = '910'
    # Supervisor contrail-discovery.ini
    $disc_port_base = '911'
    $disc_nworkers = $api_nworkers

    # Set number of config nodes
    #$cfgm_number = size($config_nodes)
    #if ($cfgm_number == 1) {
    #    $rabbitmq_conf_template = "rabbitmq_config_single_node.erb"
    #}
    #else {
    #    $rabbitmq_conf_template = "rabbitmq_config.erb"
    #}

    notify { "config_nodes: $config_nodes":; }
    $cfgm_ip_list_shell = inline_template('<%= @config_nodes.map{ |ip| "#{ip}" }.join(",") %>')
    $cfgm_name_list_shell = inline_template('<%= @config_nodes.map{ |ip| "#{ip}" }.join(",") %>')
    $rabbit_env = "NODE_IP_ADDRESS=${ipaddress}\nNODENAME=rabbit@${hostname}ctl\n"

    case $::operatingsystem {
	'Ubuntu': {
	    file {"/etc/init/supervisor-config.override": ensure => absent, require => Package['contrail-openstack-config']}
	    file {"/etc/init/neutron-server.override": ensure => absent, require => Package['contrail-openstack-config']}

	    file { "/etc/contrail/supervisord_config_files/contrail-api.ini" :
		ensure  => present,
		require => Package["contrail-openstack-config"],
		content => template("$module_name/contrail-api.ini.erb"),
	    }

	    file { "/etc/contrail/supervisord_config_files/contrail-discovery.ini" :
		ensure  => present,
		require => Package["contrail-openstack-config"],
		content => template("$module_name/contrail-discovery.ini.erb"),
	    }

    # Below is temporary to work-around in Ubuntu as Service resource fails
    # as upstart is not correctly linked to /etc/init.d/service-name
	    file { '/etc/init.d/supervisor-config':
		ensure => link,
		target => '/lib/init/upstart-job',
		before => Service["supervisor-config"]
	    }


	}
	default: {
	    # notify { "OS is $operatingsystem":; }
	}
    }
    ->
    # Ensure all needed packages are present
    package { 'contrail-openstack-config' : ensure => latest, notify => "Service[supervisor-config]"}
    if ! defined(File["/etc/contrail/ctrl-details"]) {
	if $haproxy == true {
	    $quantum_ip = "127.0.0.1"
	} else {
	    $quantum_ip = $host_control_ip
	}

	file { "/etc/contrail/ctrl-details" :
	    ensure  => present,
	    content => template("$module_name/ctrl-details.erb"),
	}
    }

    # Ensure service.token file is present with right content.
    if ! defined(File["/etc/contrail/service.token"]) {
	file { "/etc/contrail/service.token" :
	    ensure  => present,
	    content => template("$module_name/service.token.erb"),
	}
    }
    file { "/etc/sudoers.d/contrail_sudoers" :
        ensure  => present,
        mode => 0440,
        group => root,
        source => "puppet:///modules/$module_name/contrail_sudoers"
    }
    ->
    # Ensure log4j.properties file is present with right content.
    file { "/etc/ifmap-server/log4j.properties" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	content => template("$module_name/log4j.properties.erb"),
    }
    ->
    # Ensure authorization.properties file is present with right content.
    file { "/etc/ifmap-server/authorization.properties" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	content => template("$module_name/authorization.properties.erb"),
    }
    ->
    # Ensure basicauthusers.proprties file is present with right content.
    file { "/etc/ifmap-server/basicauthusers.properties" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	content => template("$module_name/basicauthusers.properties.erb"),
    }
    ->
    # Ensure publisher.properties file is present with right content.
    file { "/etc/ifmap-server/publisher.properties" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	content => template("$module_name/publisher.properties.erb"),
    }
    ->
    # Ensure all config files with correct content are present.
    file { "/etc/contrail/contrail-api.conf" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/contrail-api.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-config-nodemgr.conf" :
        ensure  => present,
        require => Package["contrail-openstack-config"],
        content => template("$module_name/contrail-config-nodemgr.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-keystone-auth.conf" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/contrail-keystone-auth.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-schema.conf" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/contrail-schema.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-svc-monitor.conf" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/contrail-svc-monitor.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-device-manager.conf" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/contrail-device-manager.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-discovery.conf" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/contrail-discovery.conf.erb"),
    }
    ->
    file { "/etc/contrail/vnc_api_lib.ini" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/vnc_api_lib.ini.erb"),
    }
    ->
    file { "/etc/contrail/contrail_plugin.ini" :
	ensure  => present,
	require => Package["contrail-openstack-config"],
	notify =>  Service["supervisor-config"],
	content => template("$module_name/contrail_plugin.ini.erb"),
    }
    ->
    # initd script wrapper for contrail-api
    file { "/etc/init.d/contrail-api" :
	ensure  => present,
	mode => 0777,
	require => Package["contrail-openstack-config"],
	content => template("$module_name/contrail-api.svc.erb"),
    }
    ->
    # initd script wrapper for contrail-discovery
    file { "/etc/init.d/contrail-discovery" :
	ensure  => present,
	mode => 0777,
	require => Package["contrail-openstack-config"],
	content => template("$module_name/contrail-discovery.svc.erb"),
    }
    # Handle rabbitmq.config changes
#    file { "/etc/contrail/add_etc_host.py" :
#	ensure  => present,
#	mode => 0755,
##	user => root,
#	group => root,
#	source => "puppet:///modules/$module_name/add_etc_host.py"
#    }
#    ->
#    exec { "add-etc-hosts" :
#	command => "python /etc/contrail/add_etc_host.py $cfgm_ip_list_shell $cfgm_name_list_shell & echo add-etc-hosts >> /etc/contrail/contrail_config_exec.out",
#	require => File["/etc/contrail/add_etc_host.py"],
#	unless  => "grep -qx add-etc-hosts /etc/contrail/contrail_config_exec.out",
#	provider => shell,
#	logoutput => $contrail_logoutput
#    }
#    ->
#    file { "/etc/contrail/form_rmq_cluster.sh" :
#	ensure  => present,
##	mode => 0755,
#	user => root,
#	group => root,
#	source => "puppet:///modules/$module_name/form_rmq_cluster.sh"
#    }
#    exec { "verify-rabbitmq" :
#	command => "/etc/contrail/form_rmq_cluster.sh $master $host_control_ip $config_ip_list & echo verify-rabbitmq >> /etc/contrail/contrail_config_exec.out",
#	require => File["/etc/contrail/form_rmq_cluster.sh"],
#	unless  => "grep -qx verify-rabbitmq /etc/contrail/contrail_config_exec.out",
#	provider => shell,
#	logoutput => $contrail_logoutput
#    }

    # run setup-pki.sh script
    if $use_certs == true {
	file { "/etc/contrail_setup_utils/setup-pki.sh" :
	    ensure  => present,
	    mode => 0755,
	    user => root,
	    group => root,
	    source => "puppet:///modules/$module_name/setup-pki.sh"
	}
	exec { "setup-pki" :
	    command => "/etc/contrail_setup_utils/setup-pki.sh /etc/contrail/ssl; echo setup-pki >> /etc/contrail/contrail_config_exec.out",
	    require => File["/etc/contrail_setup_utils/setup-pki.sh"],
	    unless  => "grep -qx setup-pki /etc/contrail/contrail_config_exec.out",
	    provider => shell,
	    logoutput => $contrail_logoutput
	}
    }
    # Execute config-server-setup scripts
    file { "/opt/contrail/bin/config-server-setup.sh":
	ensure  => present,
	mode => 0755,
	owner => root,
	group => root,
	require => File["/etc/contrail/ctrl-details", "/etc/contrail/contrail-schema.conf", "/etc/contrail/contrail-svc-monitor.conf"]
    }
    ->
    exec { "setup-config-server-setup" :
	command => "/bin/bash /opt/contrail/bin/config-server-setup.sh $operatingsystem && echo setup-config-server-setup >> /etc/contrail/contrail_config_exec.out",
	require => File["/opt/contrail/bin/config-server-setup.sh"],
	unless  => "grep -qx setup-config-server-setup /etc/contrail/contrail_config_exec.out",
	provider => shell
    }
    ->
#    file { "/opt/contrail/bin/quantum-server-setup.sh":
#	ensure  => present,
#	mode => 0755,
#	owner => root,
#	group => root,
#	require => File["/etc/contrail/ctrl-details", "/etc/contrail/contrail-schema.conf", "/etc/contrail/contrail-svc-monitor.conf"]
#    }
#    ->
#    exec { "setup-quantum-server-setup" :
#	command => "/bin/bash /opt/contrail/bin/quantum-server-setup.sh $operatingsystem && echo setup-quantum-server-setup >> /etc/contrail/contrail_config_exec.out",
#	require => File["/opt/contrail/bin/quantum-server-setup.sh"],
#	unless  => "grep -qx setup-quantum-server-setup /etc/contrail/contrail_config_exec.out",
#	provider => shell
#    }
#    ->
    exec { "provision-metadata-services" :
       command => "python /opt/contrail/utils/provision_linklocal.py --api_server_ip \"$::ipaddress\" --api_server_port 9100 --admin_user \"$keystone_admin_user\" --admin_password \"$keystone_admin_password\" --linklocal_service_name metadata --linklocal_service_ip 169.254.169.254 --linklocal_service_port 80 --ipfabric_service_ip \"$vip_name\"  --ipfabric_service_port 8775 --oper add && echo provision-metadata-services >> /etc/contrail/contrail_config_exec.out",
       provider => shell,
    }
    service { "supervisor-config" :
	enable => true,
	require => [ Package['contrail-openstack-config']],
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
