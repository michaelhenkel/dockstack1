class mymod::os (
) inherits mymod::params {
  $ks_sql = join(["mysql://keystone:",$keystone_admin_password,"@",$vip_name,".",$domain,"/keystone"],'')
  $cinder_sql = join(["mysql://cinder:",$keystone_admin_password,"@",$vip_name,".",$domain,"/cinder"],'')
  $glance_sql = join(["mysql://glance:",$keystone_admin_password,"@",$vip_name,".",$domain,"/glance"],'')
  $nova_sql = join(["mysql://nova:",$keystone_admin_password,"@",$vip_name,".",$domain,"/nova"],'')
  $neutron_sql = join(["mysql://neutron:",$keystone_admin_password,"@",$vip_name,".",$domain,"/neutron"],'')
  $ks_public_endpoint = join(["http://",$vip_name,".",$domain,":5000/"],'')
  $ks_admin_endpoint = join(["http://",$vip_name,".",$domain,":35357/"],'')
  $auth_uri = join(["http://",$vip_name,".",$domain,":5000/v2.0"],'')
  notify { "ksql $ks_sql":; }

  file { "/usr/bin/openstack-config":
    mode   => "740",
    owner  => root,
    group  => root,
    source => "puppet:///modules/mymod/openstack-config"
  }

  class { 'keystone':
    catalog_type   => 'sql',
    admin_token    => $keystone_admin_token,
    database_connection => $ks_sql,
    rabbit_host => $vip_name,
  }->
  
 class { 'keystone::roles::admin':
    email        => 'admin@example.com',
    password     => $keystone_admin_password,
    admin_tenant => 'admin',
 }->

  class { 'keystone::endpoint':
    public_address   => $vip_name,
    admin_address    => $vip_name,
    internal_address => $vip_name,
    region           => 'RegionOne'
  }

  exec { "glance-api identity_uri":
    command => "openstack-config --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://$vip_name:35357",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-api rabbit_host":
    command => "openstack-config --set /etc/glance/glance-api.conf DEFAULT rabbit_host $vip_name",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-api notification_driver":
    command => "openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver noop",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-api paste_deploy":
    command => "openstack-config --set /etc/glance/glance-api.conf paste_deploy flavor keystone",
    path    => "/usr/bin/:/bin/",
  }->
  class { 'glance::api':
    verbose           => true,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $keystone_admin_password,
    rabbit_host => $vip_name,
    database_connection => $glance_sql,
    auth_type => 'keystone',
    auth_uri => $auth_uri,
    #identity_uri => $ks_private_endpoint,
  }

  exec { "glance-registry identity_uri":
    command => "openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri http://$vip_name:35357",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-registry auth_uri":
    command => "openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$vip_name:5000/v2.0",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-registry admin_pwd":
    command => "openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken admin_password $keystone_admin_password",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-registry rabbit_host":
    command => "openstack-config --set /etc/glance/glance-registry.conf DEFAULT rabbit_host $vip_name",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-registry notification_driver":
    command => "openstack-config --set /etc/glance/glance-registry.conf DEFAULT notification_driver noop",
    path    => "/usr/bin/:/bin/",
  }->
  exec { "glance-api paste_registry":
    command => "openstack-config --set /etc/glance/glance-registry.conf paste_deploy flavor keystone",
    path    => "/usr/bin/:/bin/",
  }->
  class { 'glance::registry':
    verbose           => true,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $keystone_admin_password,
    auth_uri	      => $auth_uri,
    auth_type => 'keystone',
    rabbit_host => $vip_name,
    database_connection => $glance_sql,
  }

  class { 'glance::backend::file': }

  class { 'glance::keystone::auth':
    password         => $keystone_admin_password,
    email            => 'glance@example.com',
    public_address   => $vip_name,
    admin_address    => $vip_name,
    internal_address => $vip_name,
    region           => 'RegionOne',
  }


  $glance_api_server = join([$vip_name,"9292"],":")
  class { 'nova':
    database_connection => $nova_sql,
    rabbit_password     => 'guest',
    image_service       => 'nova.image.glance.GlanceImageService',
    glance_api_servers  => $glance_api_server,
    verbose             => true,
    rabbit_host         => $vip_name,
    ensure_package      => 'held',
    install_utilities => false,
  }

  class { 'nova::keystone::auth':
    password			 => $keystone_admin_password,
    configure_endpoint_v3	 => false,
    public_address               => $vip_name,
    admin_address                => $vip_name,
    internal_address             => $vip_name,
    region                       => 'RegionOne',
  }
  
  class { 'nova::api':
    enabled		=> true,
    admin_password	=> $keystone_admin_password,
    auth_host	        => $vip_name,
  }

  class { 'cinder':
    database_connection     => $cinder_sql,
    rabbit_password         => 'guest',
    rabbit_host             => $vip_name,
    verbose                 => true,
  }

  class { 'cinder::api':
    keystone_password       => $keystone_admin_password,
    keystone_auth_host      => $vip_name,
    package_ensure          => $cinder_api_package_ensure,
  }

  class { 'cinder::scheduler':
    scheduler_driver => 'cinder.scheduler.simple.SimpleScheduler',
  }

  class { 'neutron::keystone::auth':
    password		=> $keystone_admin_password,
    public_address	=> $vip_name,
    admin_address	=> $vip_name,
    internal_address	=> $vip_name,
  }

  class { 'neutron':
    enabled		=> true,
    rabbit_password	=> 'guest',
    rabbit_host		=> $vip_name,
    core_plugin 	=> 'neutron_plugin_contrail.plugins.opencontrail.contrail_plugin.NeutronPluginContrailCoreV2',
    service_plugins	=> [ 'neutron_plugin_contrail.plugins.opencontrail.loadbalancer.plugin.LoadBalancerPlugin' ],
    api_extensions_path => [ 'extensions:/usr/lib/python2.7/dist-packages/neutron_plugin_contrail/extensions' ],
  }


  class { 'neutron::server':
    auth_host		=> $vip_name,
    auth_password	=> $keystone_admin_password,
    auth_uri		=> $auth_uri,
    database_connection => $neutron_sql,
    sync_db		=> true,
  }

 class { 'neutron::plugins::opencontrail':
   api_server_ip              => $vip_name,
   api_server_port            => '8082',
   multi_tenancy              => true,
   contrail_extensions        => [ 'ipam:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_ipam.NeutronPluginContrailIpam',
                                   'policy:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_policy.NeutronPluginContrailPolicy',
                                   'route-table:neutron_plugin_contrail.plugins.opencontrail.contrail_plugin_vpc.NeutronPluginContrailVpc' ],
   keystone_auth_url          => $auth_uri,
   keystone_admin_user        => 'admin',
   keystone_admin_tenant_name => 'admin',
   keystone_admin_password    => $keystone_admin_password,
   keystone_admin_token       => $keystone_admin_password,
   package_ensure             => 'present',
 }

  #class { 'horizon':
  #  secret_key		=> $keystone_admin_password,
  #  keystone_url	=> $auth_uri,
  #}
 

}
