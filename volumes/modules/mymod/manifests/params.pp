class mymod::params (
){
  $common                       = hiera("common")
  $vip                          = $common['vip']
  $vip_mask                     = $common['vip_mask']
  $vip_name                     = $common['vip_name']
  $domain                       = $common['domain']
  $keystone_admin_user          = $common['keystone_admin_user']
  $keystone_admin_tenant        = $common['keystone_admin_tenant']
  $keystone_admin_password      = $common['keystone_admin_password']
  $keystone_admin_token         = $common['keystone_admin_token']
  $haproxy_user                 = $common['haproxy_user']
  $haproxy_password             = $common['haproxy_password']
  $galera_password		= $common['galera_password']

  $container                    = hiera("services")
  $haproxy_nodes                = $container['haproxy']
  $galera_nodes                 = $container['galera']
  $openstack_nodes              = $container['openstack']
  $cassandra_nodes              = $container['cassandra']
  $config_nodes                 = $container['config']
  $control_nodes                = $container['control']
  $collector_nodes              = $container['collector']
  $webui_nodes                  = $container['webui']


  $registered_services          = hiera("registered_services")
  $registered_haproxy           = $registered_services['haproxy']
  $registered_galera            = $registered_services['galera']
  $registered_openstack         = $registered_services['openstack']
  $registered_cassandra         = $registered_services['cassandra']
  $registered_config            = $registered_services['config']
  $registered_control           = $registered_services['control']
  $registered_webui             = $registered_services['webui']
  $registered_collector         = $registered_services['collector']
}
