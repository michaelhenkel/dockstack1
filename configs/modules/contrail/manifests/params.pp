class contrail::params (
    $database_ip_port = "9160",
    $analytics_data_ttl = 48,
    $analytics_config_audit_ttl = 168,
    $analytics_statistics_ttl = 24,
    $analytics_flow_ttl = 2,
    $snmp_scan_frequency = 600,
    $snmp_fast_scan_frequency = 60,
    $topology_scan_frequency = 60,
    $analytics_syslog_port = -1,
    $use_certs = False,
    $database_initial_token = 0,
    $database_dir = "/var/lib/cassandra",
    $database_minimum_diskGB = 10,
    $multi_tenancy = true,
    $quantum_port = "9697",
    $quantum_service_protocol = "http",
    $keystone_auth_protocol = "http",
    $keystone_auth_port = 35357,
    $keystone_insecure_flag = false,
    $api_nworkers = 1,
    $haproxy_flag = "disable",
    $manage_neutron = false,
    $zk_ip_port = '2181',
    $hc_interval = 5,
    $encap_priority = "VXLAN,MPLSoUDP,MPLSoGRE",
    $router_asn = "64512",
    $vgw_public_subnet = "",
    $vgw_public_vn_name = "",
    $vgw_interface = "",
    $vgw_gateway_routes = "",
    $orchestrator = "openstack",
    $redis_password = "",
    $external_bgp = "",
    $enable_lbass = false,
    $enable_ceilometer = false,
) {
    # Manifests use keystone_admin_token to refer to keystone_service_token too. Hence set
    # that varible here.
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
    $keystone_admin_token         = $common['keystone_admin_token']
    $keystone_admin_tenant        = $common['keystone_admin_tenant']
    $keystone_admin_password      = $common['keystone_admin_password']

    $haproxy                      = hiera("haproxy")
    $haproxy_user                 = $haproxy['user']
    $haproxy_password             = $haproxy['password']

    $galera                       = hiera("galera")
    $galera_password              = $galera['password']

    $registered_services          = hiera("registered_services")
    $registered_haproxy           = $registered_services['haproxy']
    $registered_galera            = $registered_services['galera']
    $registered_openstack         = $registered_services['openstack']
    $registered_cassandra         = $registered_services['cassandra']
    $registered_config            = $registered_services['config']
    $registered_control           = $registered_services['control']
    $registered_webui             = $registered_services['webui']
    $registered_collector         = $registered_services['collector']
    $ipaddress			  = $::ipaddress
    $hostname			  = $::hostname

}
