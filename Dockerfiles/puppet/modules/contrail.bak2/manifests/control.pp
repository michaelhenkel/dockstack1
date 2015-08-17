# == Class: contrail::control
#
# This class is used to configure software and services required
# to run controller module of contrail software suit.
#
# === Parameters:
#
# [*host_control_ip*]
#     IP address of the server where contrail collector is being installed.
#     if server has separate interfaces for management and control, this
#     parameter should provide control interface IP address.
#
# [*config_ip*]
#     Control interface IP address of the server where config module of
#     contrail cluster is configured. If there are multiple config nodes
#     , IP address of first config node server is specified here.
#
# [*internal_vip*]
#     Virtual IP on the control/data interface (internal network) to be used for openstack.
#     (optional) - Defaults to "".
#
# [*contrail_internal_vip*]
#     Virtual IP on the control/data interface (internal network) to be used for contrail.
#     (optional) - Defaults to "".
#
# [*use_certs*]
#     Flag to indicate whether to use certificates for authentication.
#     (optional) - Defaults to False.
#
# [*puppet_server*]
#     FQDN of puppet master, in case puppet master is used for certificates
#     (optional) - Defaults to "".
#
# [*contrail_logoutput*]
#     Variable to specify if output of exec commands is to be logged or not.
#     Values are true, false or on_failure
#     (optional) - Defaults to false
#
class contrail::control (
    $host_control_ip = $::ipaddress,
    $config_ip = $::contrail::params::config_ip_list[0],
    $internal_vip = $::contrail::params::internal_vip,
    $contrail_internal_vip = $::contrail::params::contrail_internal_vip,
    $use_certs = $::contrail::params::use_certs,
    $puppet_server = $::contrail::params::puppet_server,
    $contrail_logoutput = $::contrail::params::contrail_logoutput,
    $hostname = $::hostname,
    $keystone_user = $::contrail::params::keystone_admin_user,
    $keystone_tenant = $::contrail::params::keystone_admin_tenant,
    $keystone_password = $::contrail::params::openstack_passwd,
) inherits ::contrail::params {

    # If internal VIP is configured, use that address as config_ip.
    $config_ip_to_use = $internal_vip

    # Main class code begins here
    notify { "herhe":; }
    case $::operatingsystem {
        'Ubuntu': {
                file { ['/etc/init/supervisor-control.override',
                        '/etc/init/supervisor-dns.override'] :
                    ensure => absent,
                    require =>Package['contrail-openstack-control']
                }
            #TODO, Is this really needed?
                service { "supervisor-dns" :
                    enable => true,
                    require => [ Package['contrail-openstack-control']],
                    subscribe => File['/etc/contrail/contrail-dns.conf'],
                    ensure => running,
                }
                # Below is temporary to work-around in Ubuntu as Service resource fails
                # as upstart is not correctly linked to /etc/init.d/service-name
            file { '/etc/init.d/supervisor-control':
                ensure => link,
                target => '/lib/init/upstart-job',
                before => Service["supervisor-control"]
            }
            file { '/etc/init.d/supervisor-dns':
                ensure => link,
                target => '/lib/init/upstart-job',
                before => Service["supervisor-dns"]
            }
        }
        default: {
        }
    }
    # Ensure all needed packages are present
    package { 'contrail-openstack-control' : ensure => latest, notify => "Service[supervisor-control]"}
    ->

    # The above wrapper package should be broken down to the below packages
    # For Debian/Ubuntu - supervisor, contrail-api-lib, contrail-control, contrail-dns,
    #                      contrail-setup, contrail-nodemgr
    # For Centos/Fedora - contrail-api-lib, contrail-control, contrail-setup, contrail-libs
    #                     contrail-dns, supervisor


    # Ensure all config files with correct content are present.
    file { "/etc/contrail/contrail-dns.conf" :
	ensure  => present,
	require => Package["contrail-openstack-control"],
	content => template("$module_name/contrail-dns.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-control.conf" :
	ensure  => present,
	require => Package["contrail-openstack-control"],
	content => template("$module_name/contrail-control.conf.erb"),
    }
    ->
    file { "/etc/contrail/contrail-control-nodemgr.conf" :
        ensure  => present,
        require => Package["contrail-openstack-control"],
        content => template("$module_name/contrail-control-nodemgr.conf.erb"),
    }
    ->
    file { "/etc/contrail/vnc_api_lib.ini" :
        ensure  => present,
        content => template("$module_name/vnc_api_lib.ini.erb"),
    }
    ->
    exec { "update-rndc-conf-file" :
        command => "sudo sed -i 's/secret \"secret123\"/secret \"xvysmOR8lnUQRBcunkC6vg==\"/g' /etc/contrail/dns/rndc.conf && echo update-rndc-conf-file >> /etc/contrail/contrail_control_exec.out",
        require =>  Package["contrail-openstack-control"],
        onlyif => "test -f /etc/contrail/dns/rndc.conf",
        unless  => "grep -qx update-rndc-conf-file /etc/contrail/contrail_control_exec.out",
        provider => shell,
        logoutput => $contrail_logoutput
    }
    # Ensure the services needed are running.
    ->
    service { "supervisor-control" :
        enable => true,
        require => [ Package['contrail-openstack-control']],
        subscribe => File['/etc/contrail/contrail-control.conf'],
        ensure => running,
    }
    ->
    service { "contrail-named" :
        enable => true,
        require => [ Package['contrail-openstack-control']],
        subscribe => File['/etc/contrail/contrail-dns.conf'],
        ensure => running,
    }
    ->
    exec { "provision control" :
        command => "python /opt/contrail/utils/provision_control.py --api_server_ip $internal_vip --api_server_port 8082 --host_name $::hostname --host_ip $::ipaddress --router_asn 64512 --oper add --admin_user $keystone_admin_user --admin_password $keystone_admin_password --admin_tenant $keystone_admin_tenant",
        provider => shell,
    }
}
