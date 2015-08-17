define mymod::setconf(
     $conf_path		= '/etc/',
     $conf_service	= undef,
     $conf_file		= undef,
     $section		= undef,
     $parameter		= undef,
     $value		= undef
) {
      $cmd = join(["openstack-config --set ",$conf_path,$conf_service,"/",$conf_file," ",$section, " ", $parameter," ",$value],'')
      $exec_name = join([$conf_service,$section,$parameter],"_")
      notify { "cmd: $cmd":; }
      exec { $exec_name:
        command => $cmd,
        path    => "/usr/bin/:/bin/",
      }

}
