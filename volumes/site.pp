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
