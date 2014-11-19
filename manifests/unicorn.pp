# Class: puppet::unicorn
#
# Parameters:
# - listen_address - IP for binding the nginx
#
# Actions:
# - Configures nginx and unicorn for puppet master use. Tested only on CentOS 7
#
# Requires:
# - nginx
#
# Sample Usage:
#   class {'puppet::unicorn':
#     listen_address => '10.250.250.1',
#   }
#
# written by Tim 'bastelfreak' Meusel
# with big help from Rob 'rnelson0' Nelson

class puppet::unicorn (
  $listen_address,
){
  include nginx
  # install unicorn
  unless defined(Package['ruby-devel']) {
    package {'ruby-devel':
      ensure  => 'latest',
    }
  }
  package {'gcc':
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
    file{'get-SEL-policy':
      path    => '/usr/share/selinux/targeted/nginx.pp',
      source  => 'puppet:///modules/puppet/nginx.selmodule',
    } ->
    package {'policycoreutils':
      ensure  => 'latest',
    } ->
    selmodule{'nginx':
      ensure      => 'present',
      syncversion => true,
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

