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
