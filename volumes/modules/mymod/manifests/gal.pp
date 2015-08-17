class mymod::gal (
) inherits mymod::params {

  $hostname = $::hostname

  if(size($registered_galera) == 1){
    $cluster_string = "gcomm://"
    $gal_fqdn = join([$registered_galera[0],$domain],".")
  }
  else{
    $cluster_servers = join($registered_galera,",")
    $cluster_string = join(['gcomm://',$cluster_servers], '')
  }
  notify { "master : $gal_fqdn":; }
  notify { "openstack pwd : $keystone_admin_password":; }

  $vip_fqdn = join([$vip_name,$domain],".")

  class { 'galera':
     deb_sysmaint_password => $galera_password,
     root_password    => $galera_password,
     configure_repo => false,
     status_password => $galera_password,
     vendor_type => 'mariadb',
     galera_servers => $registered_galera,
     galera_master  => $gal_fqdn,
     override_options => { 'mysqld' => 
	{ 
           'log_error' => '/var/log/mysql/mysql_error.log',
           'user' => 'mysql',
	   'wsrep_provider' => '/usr/lib/galera/libgalera_smm.so',
           'wsrep_cluster_address' => $cluster_string,
           'wsrep_sst_method' => 'rsync',
           'wsrep_cluster_name' => 'galera_cluster',
           'binlog_format' => 'ROW',
           'default_storage_engine' => 'InnoDB',
           'innodb_autoinc_lock_mode' => '2',
           'innodb_locks_unsafe_for_binlog' => '1',
           'bind-address' => '0.0.0.0',
           'default-storage-engine' => 'innodb',
           'innodb_file_per_table' => '',
           'collation-server' => 'utf8_general_ci',
           'init-connect' => "'SET NAMES utf8'",
           'character-set-server' => 'utf8',
           'wait_timeout' => '28800',
           'connect_timeout' => '200',
           'general_log' => '1',
        } 
     }
  }
  mysql::db { 'keystone':
    user     => 'keystone',
    password => $keystone_admin_password,
    host     => $vip_fqdn,
  }
  mysql::db { 'nova':
    user     => 'nova',
    password => $keystone_admin_password,
    host     => $vip_fqdn,
  }
  mysql::db { 'cinder':
    user     => 'cinder',
    password => $keystone_admin_password,
    host     => $vip_fqdn,
  }
  mysql::db { 'glance':
    user     => 'glance',
    password => $keystone_admin_password,
    host     => $vip_fqdn,
  }
  mysql::db { 'neutron':
    user     => 'neutron',
    password => $keystone_admin_password,
    host     => $vip_fqdn,
  }
  $registered_haproxy.each |$index, $val| {
    $ha_node = join([$val,$domain],".")
    notify { "val: $ha_node":; }
    exec { "kick haproxy update":
      cwd     => "/tmp",
      command => "puppet kick $ha_node",
      path    => "/usr/bin/:/bin/",
    }
  }
}
