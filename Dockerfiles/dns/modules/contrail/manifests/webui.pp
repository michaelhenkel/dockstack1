# == Class: contrail::webui
#
# This class is used to configure software and services required
# to run webui module of contrail software suit.
#
# === Parameters:
#
# [*config_ip*]
#     Control Interface IP address of the server where config module of 
#     contrail cluster is configured. If there are multiple config nodes
#     this parameter uses IP address of first config node (index = 0).
#
# [*collector_ip*]
#     IP address of the server where analytics module of
#     contrail cluster is configured. If this host is also running
#     collector role, local host address is preferred here, else
#     one of collector nodes is chosen.
#
# [*openstack_ip*]
#     Control interface IP address of openstack node.
#
# [*database_ip_list*]
#     List of control interface IP addresses of all servers running cassandra
#     database roles.
#
# [*is_storage_master*]
#     Flag to Indicate if this server is also running contrail storage master role.A
#     (optional) - Default is false.
#
# [*keystone_ip*]
#     IP address of keystone node, if keystone is run outside openstack.
#     (optional) - Defaults to "", meaning use openstack_ip.
#
# [*internal_vip*]
#     Virtual IP for openstack nodes in case of HA configuration.
#     (Optional) - Defaults to "", meaning no HA configuration.
#
# [*contrail_internal_vip*]
#     Virtual IP for contrail config nodes in case of HA configuration.
#     (Optional) - Defaults to "", meaning no HA configuration.
#
# [*contrail_logoutput*]
#     Variable to specify if output of exec commands is to be logged or not.
#     Values are true, false or on_failure
#     (optional) - Defaults to false
#
class contrail::webui (
) inherits ::contrail::params {
    case $::operatingsystem {
        'Ubuntu': {
            file {"/etc/init/supervisor-webui.override": ensure => absent, require => Package['contrail-openstack-webui']}
            # Below is temporary to work-around in Ubuntu as Service resource fails
            # as upstart is not correctly linked to /etc/init.d/service-name
            file { '/etc/init.d/supervisor-webui':
                ensure => link,
                target => '/lib/init/upstart-job',
                before => Service["supervisor-webui"]
            }
        }
        default: {
        }
    }

    # Ensure all needed packages are present
    package { 'contrail-openstack-webui' : ensure => latest, notify => "Service[supervisor-webui]"}

    ##if ($is_storage_master != "") {
     ##   package { 'contrail-web-storage' :
     ##       ensure => latest,}
##	-> file { "storage.config.global.js":
##            path => "/usr/src/contrail/contrail-web-storage/webroot/common/config/storage.config.global.js",
##            ensure => present,
##            require => Package["contrail-web-storage"],
##            content => template("$module_name/storage.config.global.js.erb"),
##        }
##        -> Service['supervisor-webui']
##    } else {
##        package { 'contrail-web-storage' :
##            ensure => absent,}
##	-> file { "storage.config.global.js":
##            path => "/usr/src/contrail/contrail-web-storage/webroot/common/config/storage.config.global.js",
##            ensure => absent,
##            content => template("$module_name/storage.config.global.js.erb"),
##        }
##        -> Service['supervisor-webui']
##    }
    # The above wrapper package should be broken down to the below packages
    # For Debian/Ubuntu - contrail-nodemgr, contrail-webui, contrail-setup, supervisor
    # For Centos/Fedora - contrail-api-lib, contrail-webui, contrail-setup, supervisor
    # Ensure global config js file is present.
    file { "/etc/contrail/config.global.js" :
        ensure  => present,
        require => Package["contrail-openstack-webui"],
        content => template("$module_name/config.global.js.erb"),
    }
    ->
    # Ensure the services needed are running. The individual services are left
    # under control of supervisor. Hence puppet only checks for continued operation
    # of supervisor-webui service, which in turn monitors status of individual
    # services needed for webui role.
    service { "supervisor-webui" :
        enable => true,
        subscribe => File['/etc/contrail/config.global.js'],
        ensure => running,
    }
}
