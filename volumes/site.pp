  class { '::mymod::ha': }
  class { '::mymod::ka': }
}
  class { '::contrail::common': }
  class { '::contrail::compute': }
}
node 'ha1.endor.lab' {
  class { '::mymod::ha': }
  class { '::mymod::ka': }
}
node 'gal1.endor.lab' {
  class { '::mymod::gal': }
}
node 'os1.endor.lab' {
  class { '::mymod::os': }
}
node 'cas1.endor.lab' {
  class { '::contrail::common': }
  class { '::contrail::database': }
}
node 'conf1.endor.lab' {
  class { '::contrail::common': }
  class { '::contrail::config': }
}
node 'col1.endor.lab' {
  class { '::contrail::common': }
  class { '::contrail::collector': }
}
node 'ctrl1.endor.lab' {
  class { '::contrail::common': }
  class { '::contrail::control': }
}
node 'webui1.endor.lab' {
  class { '::contrail::common': }
  class { '::contrail::webui': }
}
