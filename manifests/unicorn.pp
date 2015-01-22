# Class: puppet::unicorn
#
# Parameters:
#  ['listen_address']     - IP for binding the webserver, defaults to *
#  ['puppet_proxy_port']  - The port for the virtual host
#  ['disable_ssl']        - Disables SSL on the webserver. usefull if you use this master behind a loadbalancer. currently only supported by nginx, defaults to undef
#  ['backup_upstream']    - specify another puppet master as fallback. currently only supported by nginx
#
# Actions:
# - Configures nginx and unicorn for puppet master use. Tested only on CentOS 7
#
# Requires:
# - nginx
#
# Sample Usage:
#   class {'puppet::unicorn':
#     listen_address    => '10.250.250.1',
#     puppet_proxy_port => '8140',
#   }
#
# written by Tim 'bastelfreak' Meusel
# with big help from Rob 'rnelson0' Nelson and the_scourge

class puppet::unicorn (
  $listen_address,
  $puppet_proxy_port,
  $disable_ssl,
  $backup_upstream,
){
  include nginx
  # install unicorn
  unless defined(Package['ruby-devel']) {
    package {'ruby-devel':
      ensure  => 'latest',
    }
  }
  package { [ 'policycoreutils-python', 'gcc' ]:
    ensure  => 'latest',
  } ->
  package {['unicorn', 'rack']:
    ensure    => 'latest',
    provider  => 'gem',
    require   => Package['ruby-devel'],
  } ->
  file {'copy-config':
    path    => '/etc/puppet/config.ru',
    source  => '/usr/share/puppet/ext/rack/config.ru',
  } ->
  file {'unicorn-conf':
    path    => '/etc/puppet/unicorn.conf',
    source  => 'puppet:///modules/puppet/unicorn.conf',
  } ->
  file {'unicorn-service':
    path    => '/usr/lib/systemd/system/unicorn-puppetmaster.service',
    source  => 'puppet:///modules/puppet/unicorn-puppetmaster.service',
    notify  => Exec['systemd-reload'],
  } ->
  exec{'systemd-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    notify      => Service['unicorn-puppetmaster'],
  }
  unless defined(Service['unicorn-puppetmaster']) {
    service{'unicorn-puppetmaster':
      ensure  => 'running',
      enable  => true,
      require => Exec['systemd-reload'],
    }
  }
  # update SELinux
  if $::selinux_config_mode == 'enforcing' {
    package {['policycoreutils', 'checkpolicy']:
      ensure  => 'latest',
    } ->
    file {'selinux template':
      path    =>  '/tmp/nginx.te',
      ensure  =>  file,
      content =>  template('puppet/unicorn_selinux_template'),
      notify  => Exec['building_selinux_module_from_template'],
    }
    exec {'building_selinux_module_from_template':
      path        => [ "/usr/bin", "/usr/local/bin" ],
      command     => 'checkmodule -M -m -o /tmp/nginx.mod /tmp/nginx.te',
      refreshonly => true,
      notify      => Exec['building_selinux_policy_package_from_module'],
    }
    exec {'building_selinux_policy_package_from_module':
      path        => [ "/usr/bin", "/usr/local/bin" ],
      command     => 'semodule_package -o /tmp/nginx.pp -m /tmp/nginx.mod',
      refreshonly => true,
    }
    file {'/usr/share/selinux/targeted/nginx.pp':
      source => 'file:///tmp/nginx.pp',
      require => Exec['building_selinux_policy_package_from_module'],
    }
    selmodule {'nginx':
      ensure      => 'present',
      syncversion => true,
      require     => File['/usr/share/selinux/targeted/nginx.pp'],
    }
  }
  # hacky vhost
  file {'puppetmaster-vhost':
    path    => '/etc/nginx/sites-available/puppetmaster',
    content => template('puppet/puppetmaster'),
  } ->
  file {'enable-puppetmaster-vhost':
    ensure  => 'link',
    path    => '/etc/nginx/sites-enabled/puppetmaster',
    target  => '/etc/nginx/sites-available/puppetmaster',
    notify  => Service['nginx'],
  }
  unless defined(Service['nginx']) {
    service{'nginx':
      ensure  => 'running',
      enable  => true,
      require => File['enable-puppetmaster-vhost'],
    }
  }
}

