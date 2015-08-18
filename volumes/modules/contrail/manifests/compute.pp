# This class is used to configure software and services required
# to run compute module (vrouter and agent) of contrail software suit.
#
# === Parameters:
#
# [*host_control_ip*]
#     IP address of the server.
#     If server has separate interfaces for management and control, this
#     parameter should provide control interface IP address.
#
# [*config_ip*]
#     Control interface IP address of the server where config module of
#     contrail cluster is configured. If there are multiple config nodes,
#     specify address of first config node. Actual value used by this module
#     logic would be contrail_internal_vip or internal_vip, if those are 
#     specified for HA setup.
#
# [*openstack_ip*]
#     IP address of server running openstack services. If the server has
#     separate interfaces for management and control, this parameter
#     should provide control interface IP address.
#
# [*control_ip_list*]
#     List of IP addresses running contrail controller module. This is used
#     to derive number of control nodes (needed to be added to config file).
#
# [*compute_ip_list*]
#     List of IP addresses running contrail compute module. This is used
#     to decide is nfs is to be created, this is done on first node only.
#
# [*keystone_ip*]
#     IP address of server running keystone service. Should be specified if
#     keystone is running on a server other than openstack server.
#     (optional) - Defaults to "", meaning use openstack_ip.
#
# [*keystone_service_token*]
#     openstack service token value.
#     (optional) - Defaults to "c0ntrail123"
#
# [*keystone_auth_protocol*]
#     Keystone authentication protocol.
#     (optional) - Defaults to "http".
#
# [*keystone_auth_port*]
#     Keystone authentication port.
#     (optional) - Defaults to "35357".
#
# [*openstack_manage_amqp*]
#     flag to indicate if amqp service is managed by openstack node or contrail
#     config node. amqp_server_ip is set based on value of this flag. If false,
#     use contrail_internal_vip or config_ip. If true, use internal_vip or
#     openstack_ip. Note : If amqp_server_ip is specifically provided (next param)
#     that value is used regardless of value of manage_amqp flag.
#     (optional) - Defaults to false, meaning contrail config to manage amqp.
#
# [*amqp_server_ip*]
#     If Rabbitmq is running on a different server, specify its IP address here.
#     (optional) - Defaults to "".
#
# [*openstack_mgmt_ip*]
#     Management interface address of openstack node (if management and control are separate
#     interfaces on that node)
#     (optional) - Defaults to "", meaning use openstack_ip.
#
# [*neutron_service_protocol*]
#     Neutron Service protocol.
#     (optional) - Defaults to "http".
#
# [*keystone_admin_user*]
#     Keystone admin user.
#     (optional) - Defaults to "admin".
#
# [*keystone_admin_password*]
#     Keystone admin password.
#     (optional) - Defaults to "contrail123"
#
# [*keystone_admin_tenant*]
#     Keystone admin tenant name.
#     (optional) - Defaults to "admin".
#
# [*haproxy*]
#     whether haproxy is configured and enabled. If internal_vip or contrail_internal_vip
#     is specified, value of false is used by the logic in this module.
#     (optional) - Defaults to false. 
#
# [*host_non_mgmt_ip*]
#     Specify address of data/control interface, only if there are separate interfaces
#     for management and data/control. If system has single interface for both, leave
#     default value of "".
#     (optional) - Defaults to "".
#
# [*host_non_mgmt_gateway*]
#     Gateway IP address of the data interface of the server. If server has separate
#     interfaces for management and control/data, this parameter should provide gateway
#     ip address of data interface.
#     (optional) - Defaults to "".
#
# [*metadata_secret*]
#     metadata secret value from openstack node.
#     (optional) - Defaults to "". 
#
# [*quantum_port*]
#     Quantum port number
#     (optional) - Defaults to "9697"
#
# [*quantum_service_protocol*]
#     Quantum Service protocol value (http or https)
#     (optional) - Defaults to "http".
#
# [*internal_vip*]
#     Virtual mgmt IP address for openstack modules
#     (optional) - Defaults to ""
#
# [*external_vip*]
#     Virtual control/data IP address for openstack modules
#     (optional) - Defaults to ""
#
# [*contrail_internal_vip*]
#     Virtual mgmt IP address for contrail modules
#     (optional) - Defaults to ""
#
# [*vmware_ip*]
#     VM IP address (for ESXi/VMware host)
#     (optional) - Defaults to ""
#
# [*vmware_username*]
#     VM er name (for ESXi/VMware host)
#     (optional) - Defaults to ""
#
# [*vmware_password*]
#     VM password (for ESXi/VMware host)
#     (optional) - Defaults to ""
#
# [*vswitch*]
#     vswitch value (for ESXi/VMware host)
#     (optional) - Defaults to ""
#
# [*vgw_public_subnet*]
#     Public subnet value for virtual gateway configuration.
#     (optional) - Defaults to ""
#
# [*vgw_public_vn_name*]
#     Public virtual network name value for virtual gateway configuration.
#     (optional) - Defaults to ""
#
# [*vgw_interface*]
#     Interface name for virtual gateway configuration.
#     (optional) - Defaults to ""
#
# [*vgw_gateway_routes*]
#     Gateway routes for virtual gateway configuration.
#     (optional) - Defaults to ""
#
# [*nfs_server*]
#     nfs server address for storage
#     (optional) - Defaults to ""
#
# [*orchestrator*]
#     orchestrator being used for launching VMs.
#     (optional) - Defaults to "openstack"
#
# [*contrail_logoutput*]
#     Variable to specify if output of exec commands is to be logged or not.
#     Values are true, false or on_failure
#     (optional) - Defaults to false
#
class contrail::compute (
    $neutron_service_protocol = $::contrail::params::neutron_service_protocol,
) inherits ::contrail::params {
    $control_node_list = keys($control_nodes)
    $contrail_num_controls = inline_template("<%= @control_node_list.length %>")
    $keystone_ip_to_use = $vip_name
    $amqp_server_ip_to_use = $vip_name

    # set number of control nodes.
    $number_control_nodes = size($control_ip_list)
    # Set vhost_ip and multi_net flag
    $vhost_ip = $::ipaddress
    $physical_dev = get_device_name("$vhost_ip")
    $contrail_compute_dev = ""
    $contrail_dev_mac = $::macaddress
    $contrail_dev = $physical_dev
    $contrail_macaddr = $contrail_dev_mac
    $contrail_netmask = $::netmask
    $contrail_cidr = convert_netmask_to_cidr($contrail_netmask)
    $contrail_gway = $::gateway
    $quantum_ip = $vip_name
    $discovery_ip = $vip_name
    $hypervisor_type = "kvm"
    $contrail_agent_mode = ""

    #Determine vrouter package to be installed based on the kernel
    #TODO add DPDK support here


    $vrouter_pkg = "contrail-vrouter-dkms" 


    # Main code for class starts here
    # Ensure all needed packages are latest
    package { 'contrail-vrouter-dkms' : 
                ensure => latest,
                install_options => '--force-yes'
    }->
    package { 'contrail-openstack-vrouter' : 
                ensure => latest,
                install_options => '--force-yes'
    }



    if ($operatingsystem == "Ubuntu"){
	file {"/etc/init/supervisor-vrouter.override": ensure => absent, require => Package['contrail-openstack-vrouter']}
    }

    # Set Neutron Admin auth URL (should be done only for ubuntu)
    exec { "exec-compute-neutron-admin" :
	command => "echo \"neutron_admin_auth_url = http://$vip_name:5000/v2.0\" >> /etc/nova/nova.conf && echo exec-compute-neutron-admin >> /etc/contrail/contrail_compute_exec.out",
	require => [ Package["contrail-openstack-vrouter"] ],
	provider => shell
    } ->

    # set rpc backend in nova.conf
    exec { "exec-compute-update-nova-conf" :
        command => "sed -i \"s/^rpc_backend = nova.openstack.common.rpc.impl_qpid/#rpc_backend = nova.openstack.common.rpc.impl_qpid/g\" /etc/nova/nova.conf && echo exec-update-nova-conf >> /etc/contrail/contrail_common_exec.out",
	require => [ Package["contrail-openstack-vrouter"] ],
        provider => shell
    }

    if ! defined(Exec["neutron-conf-exec"]) {
	exec { "neutron-conf-exec":
	    command => "sudo sed -i 's/rpc_backend\s*=\s*neutron.openstack.common.rpc.impl_qpid/#rpc_backend = neutron.openstack.common.rpc.impl_qpid/g' /etc/neutron/neutron.conf && echo neutron-conf-exec >> /etc/contrail/contrail_openstack_exec.out",
	    onlyif => "test -f /etc/neutron/neutron.conf",
	    unless  => "grep -qx neutron-conf-exec /etc/contrail/contrail_openstack_exec.out",
	    require => [ Package["contrail-openstack-vrouter"] ],
	    provider => shell
	}
    }

    file { "/etc/contrail/contrail_setup_utils/add_dev_tun_in_cgroup_device_acl.sh":
        ensure  => present,
        mode => 0755,
        owner => root,
        group => root,
        source => "puppet:///modules/$module_name/add_dev_tun_in_cgroup_device_acl.sh"
    }

    exec { "add_dev_tun_in_cgroup_device_acl" :
        command => "./add_dev_tun_in_cgroup_device_acl.sh && echo add_dev_tun_in_cgroup_device_acl >> /etc/contrail/contrail_compute_exec.out",
	cwd => "/etc/contrail/contrail_setup_utils/",
        require => [ File["/etc/contrail/contrail_setup_utils/add_dev_tun_in_cgroup_device_acl.sh"] ,Package['contrail-openstack-vrouter'] ],
        unless  => "grep -qx add_dev_tun_in_cgroup_device_acl /etc/contrail/contrail_compute_exec.out",
        provider => shell,
        logoutput => $contrail_logoutput
    }

    file { "/etc/contrail/vrouter_nodemgr_param" :
	ensure  => present,
	require => Package["contrail-openstack-vrouter"],
	content => template("$module_name/vrouter_nodemgr_param.erb"),
    }

    # Ensure ctrl-details file is present with right content.
    if ! defined(File["/etc/contrail/ctrl-details"]) {
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

    if ($physical_dev != undef and $physical_dev != "vhost0") {
	file { "/etc/contrail/contrail_setup_utils/update_dev_net_config_files.py":
	    ensure  => present,
	    mode => 0755,
	    owner => root,
	    group => root,
	    source => "puppet:///modules/$module_name/update_dev_net_config_files.py"
	}
        $update_dev_net_cmd = "/bin/bash -c \"python /etc/contrail/contrail_setup_utils/update_dev_net_config_files.py --vhost_ip $vhost_ip $multinet_opt --dev \'$physical_dev\' --compute_dev \'$contrail_compute_dev\' --netmask \'$contrail_netmask\' --gateway \'$contrail_gway\' --cidr \'$contrail_cidr\' --host_non_mgmt_ip \'$host_non_mgmt_ip\' --mac $contrail_macaddr && echo update-dev-net-config >> /etc/contrail/contrail_compute_exec.out\""

	notify { "Update dev net config is $update_dev_net_cmd":; }

	exec { "update-dev-net-config" :
	    command => $update_dev_net_cmd,
	    require => [ File["/etc/contrail/contrail_setup_utils/update_dev_net_config_files.py"] ],
	    unless  => "grep -qx update-dev-net-config /etc/contrail/contrail_compute_exec.out",
	    provider => shell,
	} 

    } else {
        #Not needed for now, as compute upgrade anyways goes for a reboot,
        #On 14.04, since network restart is not supported,
        #We need to stop vrouter, modprobe -r vrouter and start vrouter again.
        #
        /*
	exec { "service_network_restart" :
	    command => "/etc/init.d/networking restart && echo service_network_restart >> /etc/contrail/contrail_compute_exec.out",
	    require => Package["contrail-openstack-vrouter"],
	    unless  => "grep -qx service_network_restart /etc/contrail/contrail_compute_exec.out",
	    provider => shell,
	    logoutput => $contrail_logoutput
	}
        ->
        */
    }

    file { "/etc/contrail/default_pmac" :
	ensure  => present,
	require => Package["contrail-openstack-vrouter"],
	content => template("$module_name/default_pmac.erb"),
    } ->
    file { "/etc/contrail/agent_param" :
	ensure  => present,
	require => Package["contrail-openstack-vrouter"],
	content => template("$module_name/agent_param.tmpl.erb"),
    }
    if ! defined(File["/etc/contrail/vnc_api_lib.ini"]) {
	file { "/etc/contrail/vnc_api_lib.ini" :
	    ensure  => present,
	    require => Package["contrail-openstack-vrouter"],
	    content => template("$module_name/vnc_api_lib.ini.erb"),
	}
    }
    file { "/etc/contrail/contrail-vrouter-agent.conf" :
	ensure  => present,
	require => Package["contrail-openstack-vrouter"],
	content => template("$module_name/contrail-vrouter-agent.conf.erb"),
    } ->
    file { "/etc/contrail/contrail-vrouter-nodemgr.conf" :
        ensure  => present,
        require => Package["contrail-openstack-vrouter"],
        content => template("$module_name/contrail-vrouter-nodemgr.conf.erb"),
    } ->


    file { "/opt/contrail/utils/provision_vrouter.py":
	ensure  => present,
	mode => 0755,
	owner => root,
	group => root
    }
    exec { "add-vnc-config" :
	command => "/bin/bash -c \"python /opt/contrail/utils/provision_vrouter.py --host_name $::hostname --host_ip $::ipaddress --api_server_ip $vip --api_server_port 8082 --admin_user $keystone_admin_user --admin_password $keystone_admin_password --admin_tenant_name $keystone_admin_tenant --openstack_ip $vip --router_type vrouter && echo add-vnc-config >> /etc/contrail/contrail_compute_exec.out\"",
	require => File["/opt/contrail/utils/provision_vrouter.py"],
	provider => shell,
    } ->
#provision_vrouter.py  --host_name compute1.endor.lab --host_ip 192.168.1.181 --api_server_ip 10.0.0.254 --api_server_port 8082 --admin_user admin --admin_password ladakh1 --admin_tenant_name admin --openstack_ip 10.0.0.254 --router_type vrouter

    file { "/opt/contrail/bin/compute-server-setup.sh":
	ensure  => present,
	mode => 0755,
	owner => root,
	group => root,
	require => File["/etc/contrail/ctrl-details"],
    } ->
    exec { "setup-compute-server-setup" :
	command => "/opt/contrail/bin/compute-server-setup.sh; echo setup-compute-server-setup >> /etc/contrail/contrail_compute_exec.out",
	require => File["/opt/contrail/bin/compute-server-setup.sh"],
	unless  => "grep -qx setup-compute-server-setup /etc/contrail/contrail_compute_exec.out",
	provider => shell,
    } ->
    exec { "fix-neutron-tenant-name" :
	command => "openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_tenant_name services && echo fix-neutron-tenant-name >> /etc/contrail/contrail_compute_exec.out",
	unless  => "grep -qx fix-neutron-tenant-name /etc/contrail/contrail_compute_exec.out",
	provider => shell,

    } ->
    exec { "fix-neutron-admin-password" :
	command => "openstack-config --set /etc/nova/nova.conf DEFAULT neutron_admin_password $keystone_admin_password && echo fix-neutron-admin-password >> /etc/contrail/contrail_compute_exec.out",
	unless  => "grep -qx fix-neutron-admin-password /etc/contrail/contrail_compute_exec.out",
	provider => shell,

    } ->
    exec { "fix-keystone-admin-password" :
	command => "openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password $keystone_admin_password && echo fix-keystone-admin-password >> /etc/contrail/contrail_compute_exec.out",
	unless  => "grep -qx fix-keystone-admin-password /etc/contrail/contrail_compute_exec.out",
	provider => shell,

    }
    -> 
    service { "supervisor-vrouter" :
	enable => true,
	require => [ Package['contrail-openstack-vrouter']
		 ],
	ensure => running,
    }
    ->
    service { "nova-compute" :
	enable => true,
	require => [ Package['contrail-openstack-vrouter']
		 ],
	ensure => running,
    }

    # Now reboot the system
}
