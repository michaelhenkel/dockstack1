# == Class: contrail::common
#
# This class is used to configure software and services common
# to all contrail modules.
#
# === Parameters:
#
# [*host_mgmt_ip*]
#     IP address of the server where contrail modules are being installed.
#     if server has separate interfaces for management and control, this
#     parameter should provide management interface IP address.
#
# [*contrail_repo_name*]
#     Name of contrail repo being used to provision the contrail roles.
#     Version of contrail software being used is specified here.
#
# [*contrail_repo_ip*]
#     IP address of the server where contrail repo is mirrored. This is
#     same as the cobbler address or server manager IP address (puppet master).
#
# [*contrail_repo_type*]
#     Type of contrail repo (contrail-ubuntu-package or contrail-centos-package).
#
# [*contrail_logoutput*]
#     Variable to specify if output of exec commands is to be logged or not.
#     Values are true, false or on_failure
#     (optional) - Defaults to false
#
class contrail::common(
) inherits ::contrail::params {

    notify { "**** $module_name - host_mgmt_ip = $host_mgmt_ip": ; }
    package { 'libssl0.9.8' : ensure => present,}
    if ($operatingsystem == "Ubuntu") {
	file { '/sbin/chkconfig':
	    ensure => link,
	    target => '/bin/true'
	}
    }

    if ($operatingsystem == "Ubuntu") {
	exec { "core-file-unlimited" :
	    command   => "ulimit -c unlimited",
	    unless    => "ulimit -c | grep -qi unlimited",
	    provider  => shell,
	    logoutput => $contrail_logoutput
	}
    }

    exec { 'core_pattern_1':
	command   => 'echo \'kernel.core_pattern = /var/crashes/core.%e.%p.%h.%t\' >> /etc/sysctl.conf',
	unless    => "grep -q 'kernel.core_pattern = /var/crashes/core.%e.%p.%h.%t' /etc/sysctl.conf",
	provider => shell,
	logoutput => $contrail_logoutput
    }

    file { "/var/crashes":
	ensure => "directory",
    }

    file { ["/etc/contrail", "/etc/contrail/contrail_setup_utils"] :
	ensure => "directory",
    }

    file { "/etc/contrail/contrail_setup_utils/enable_kernel_core.py":
	ensure  => present,
	mode => 0755,
	owner => root,
	group => root,
	source => "puppet:///modules/$module_name/enable_kernel_core.py"
    }

    exec { "enable-kernel-core" :
	#command => "python /etc/contrail/contrail_setup_utils/enable_kernel_core.py && echo enable-kernel-core >> /etc/contrail/contrail_common_exec.out",
	command => "python /etc/contrail/contrail_setup_utils/enable_kernel_core.py; echo enable-kernel-core >> /etc/contrail/contrail_common_exec.out",
	require => File["/etc/contrail/contrail_setup_utils/enable_kernel_core.py" ],
	unless  => "grep -qx enable-kernel-core /etc/contrail/contrail_common_exec.out",
	provider => shell,
	logoutput => $contrail_logoutput
    }
    file { "/tmp/facts.yaml":
        content => inline_template("<%= scope.to_hash.reject { |k,v| !( k.is_a?(String) && v.is_a?(String) ) }.to_yaml %>"),
    } 

    file { "/etc/contrail/contrail_setup_utils/add_reserved_ports.py" :
	ensure  => present,
	mode => 0755,
	group => root,
	require => File["/etc/contrail/contrail_setup_utils"],
	source => "puppet:///modules/$module_name/add_reserved_ports.py"
    }
    ->
    exec { "add_reserved_ports" :
	command => "python add_reserved_ports.py 35357,35358,33306 && echo add_reserved_ports >> /etc/contrail/contrail_common_exec.out",
	cwd => "/etc/contrail/contrail_setup_utils/",
	unless  => "grep -qx add_reserved_ports /etc/contrail/contrail_common_exec.out",
	provider => shell,
	logoutput => $contrail_logoutput
    }
    class { 'ntp': 
       servers => ['127.127.1.0'],
       fudge  => ['127.127.1.0 stratum 5']
    }
    #service { "ntp" :
    #    enable => true,
    #    ensure => running,
   #}
}
