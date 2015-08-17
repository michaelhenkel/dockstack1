class contrail::database (
    $database_minimum_diskGB = $::contrail::params::database_minimum_diskGB,
    $hostname = $::hostname
) inherits ::contrail::params {
#) {
    # Main Class code
    $ipaddress = $::ipaddress
    $database_initial_token = "token"
    $database_dir = "/var/lib/cassandra"
    $contrail_cassandra_dir = "/etc/cassandra"
    file {"/etc/init/supervisord-contrail-database.override":
            ensure => absent,
            require => Package['contrail-openstack-database']
    }

    # set database_index
    $database_index = inline_template('<%= @registered_cassandra.index(@hostname) %>')

    # set cassandra_seeds list
    if (size($registered_cassandra) > 1) {
        $cassandra_seeds = difference($registered_cassandra, [$hostname])
    }
    else {
        $cassandra_seeds = $registered_cassandra
    }
    notify { "zoo list: $registered_cassandra":;}
    $zk_ip_list_for_shell = inline_template('<%= @registered_cassandra.map{ |ip| "#{ip}" }.join(" ") %>')
    notify { "zk_ip_list_for_shell: $zk_ip_list_for_shell":;}
    $contrail_zk_exec_cmd = "/bin/bash /etc/contrail/contrail_setup_utils/config-zk-files-setup.sh $operatingsystem $database_index $zk_ip_list_for_shell && echo setup-config-zk-files-setup >> /etc/contrail/contrail-config-exec.out"

    file { "$database_dir/ContrailAnalytics":
            ensure => link,
            target => "$analytics_data_dir/ContrailAnalytics",
            require => File["$database_dir"],
            notify => Service["supervisor-database"]
    }
    # Ensure all needed packages are present
    package { 'contrail-openstack-database' : ensure => latest}
    ->
    # database venv installation
    exec { "database-venv" :
        command   => '/bin/bash -c "source ../bin/activate && pip install * && echo database-venv >> /etc/contrail/contrail_database_exec.out"',
        cwd       => '/opt/contrail/database-venv/archive',
        unless    => [ "[ ! -d /opt/contrail/database-venv/archive ]",
                       "[ ! -f /opt/contrail/database-venv/bin/activate ]",
                       "grep -qx database-venv /etc/contrail/contrail_database_exec.out"],
        require   => Package['contrail-openstack-database'],
        provider => "shell",
        logoutput => $contrail_logoutput
    }
    ->
    file { "$database_dir" :
        ensure  => directory,
        require => Package['contrail-openstack-database']
    }
    ->
    file { "$contrail_cassandra_dir/cassandra.yaml" :
        ensure  => present,
        require => [ Package['contrail-openstack-database'] ],
        content => template("$module_name/cassandra.yaml.erb"),
    }
    ->
    file { "$contrail_cassandra_dir/cassandra-env.sh" :
        ensure  => present,
        require => [ Package['contrail-openstack-database'] ],
        content => template("$module_name/cassandra-env.sh.erb"),
    }
    # Below is temporary to work-around in Ubuntu as Service resource fails
    # as upstart is not correctly linked to /etc/init.d/service-name
    file { '/etc/init.d/supervisord-contrail-database':
        ensure => link,
        target => '/lib/init/upstart-job',
        require => File["$contrail_cassandra_dir/cassandra-env.sh"]
    }
    # set high session timeout to survive glance led disk activity
    file { "/etc/contrail/contrail_setup_utils/config-zk-files-setup.sh":
        ensure  => present,
        mode => 0755,
        owner => root,
        group => root,
        require => Package["contrail-openstack-database"],
        source => "puppet:///modules/$module_name/config-zk-files-setup.sh"
    }
    ->
    notify { "contrail contrail_zk_exec_cmd is $contrail_zk_exec_cmd":; }
    ->
    exec { "setup-config-zk-files-setup" :
        command => $contrail_zk_exec_cmd,
        require => File["/etc/contrail/contrail_setup_utils/config-zk-files-setup.sh"],
        unless  => "grep -qx setup-config-zk-files-setup /etc/contrail/contrail-config-exec.out",
        provider => shell,
    }
    ->
    file { "/etc/contrail/contrail-nodemgr-database.conf" :
	ensure  => present,
	content => template("$module_name/contrail-nodemgr-database.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-database-nodemgr.conf" :
        ensure  => present,
        content => template("$module_name/contrail-database-nodemgr.conf.erb"),
    }
    ->
    file { "/etc/contrail/database_nodemgr_param" :
	ensure  => present,
	content => template("$module_name/database_nodemgr_param.erb"),
    }
    ->
    file { "/opt/contrail/bin/database-server-setup.sh":
	ensure  => present,
	mode => 0755,
	owner => root,
	group => root,
    }
    exec { "setup-database-server-setup" :
	command => "/opt/contrail/bin/database-server-setup.sh; echo setup-database-server-setup >> /etc/contrail/contrail-compute-exec.out",
	require => File["/opt/contrail/bin/database-server-setup.sh"],
	unless  => "grep -qx setup-database-server-setup /etc/contrail/contrail-compute-exec.out",
	provider => shell,
	logoutput => $contrail_logoutput
    }
    ->
    service { "supervisor-database" :
        enable => true,
        require => [ Package["contrail-openstack-database"],
                     Exec['database-venv'] ],
        subscribe => [ File["$contrail_cassandra_dir/cassandra.yaml"],
                       File["$contrail_cassandra_dir/cassandra-env.sh"] ],
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
