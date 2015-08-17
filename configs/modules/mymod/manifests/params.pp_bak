class mymod::params (
){
  $common                       = hiera("common")
  $vip                          = $common['vip']
  $vip_mask                     = $common['vip_mask']
  $vip_name                     = $common['vip_name']
  $domain                       = $common['domain']
  $galera_nodes                 = $common['galera_nodes']
  $openstack_nodes              = $common['openstack_nodes']
  $cassandra_nodes              = $common['cassandra_nodes']
  $config_nodes                 = $common['config_nodes']
  $control_nodes                = $common['control_nodes']
  $collector_nodes              = $common['collector_nodes']
  $webui_nodes                  = $common['webui_nodes']
  $keystone_admin_user          = $common['keystone_admin_user']
  $keystone_admin_tenant        = $common['keystone_admin_tenant']
  $keystone_admin_password      = $common['keystone_admin_password']
  $keystone_admin_token         = $common['keystone_admin_token']

  $haproxy                      = hiera("haproxy")
  $haproxy_user                 = $haproxy['user']
  $haproxy_password             = $haproxy['password']

  $galera			= hiera("galera")
  $galera_password		= $galera['password']

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
