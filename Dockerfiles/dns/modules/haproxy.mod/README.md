PuppetLabs Module for haproxy (phrawzty remix)
==============================================

HAProxy is an HA proxying daemon for load-balancing to clustered services. It
can proxy TCP directly, or other kinds of traffic such as HTTP.

This module is based on Puppetlabs' official HAProxy module; however, it has
been "remixed" for use at Mozilla. There are two major areas where the original
module has been changed :

 * Storeconfigs, while present, are no longer required.
 * The "listen" stanza format has been abandoned in favour of a frontend /
   backend style configuration.

Basic Usage 
-----------

A very simple configuration to proxy unrelated Redis nodes :

```puppet
  class { 'haproxy': }

  haproxy::frontend { 'in_redis':
    ipaddress       => $::ipaddress,
    ports           => '6379',
    default_backend => 'out_redis',
    options         => { 'balance' => 'roundrobin' }
  }

  haproxy::backend { 'out_redis':
    listening_service => 'redis',
    server_names      => ['node01', 'node02'],
    ipaddresses       => ['node01.redis.server.foo', 'node02.redis.server.foo'],
    ports             => '6379',
    options           => 'check'
  }
```

Configuring haproxy options
---------------------------

The base `haproxy` class can accept two parameters which will configure basic
behaviour of the haproxy server daemon:

- `global_options` to configure the `global` section in `haproxy.cfg`
- `defaults_options` to configure the `defaults` section in `haproxy.cfg`

Configuring haproxy daemon listener (frontend)
----------------------------------------------

One `haproxy::frontend` defined resource should be defined for each HAProxy
loadbalanced set of backend servers. The title of the `haproxy::frontend`
resource is the key to which balancer members will be proxied to. The
`ipaddress` field should be the public ip address which the loadbalancer will
be contacted on. The `ports` attribute can accept an array or comma-separated
list of ports which should be proxied to the `haproxy::backend` nodes.

Configuring haproxy loadbalanced member nodes (backend)
-------------------------------------------------------

The `haproxy::backend` resource should be defined for every backend service
that is serving loadbalanced traffic. The `listening_service` attribute will
associate it with `haproxy::frontend` directives on the haproxy node.
`ipaddresses` and `ports` will be assigned to the member to be contacted on. If
an array of `ipaddresses` and `server_names` are provided then they will be
added to the config in lock-step.

If you're not using storeconfigs, then `listening_service` is useless - just
put whatever you want in there. :P

Dependencies
------------

 * Tested and built on Ubuntu and CentOS.
 * Requires ripienaar's excellent puppet-concat(https://github.com/ripienaar/puppet-concat) module.

Copyright and License
---------------------

Copyright (C) 2012 [Puppet Labs](https://www.puppetlabs.com/) Inc

Puppet Labs can be contacted at: info@puppetlabs.com

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License.  You may obtain a copy of the
License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied.  See the License for the
specific language governing permissions and limitations under the License.
