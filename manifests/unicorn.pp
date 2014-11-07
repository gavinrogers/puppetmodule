# this class installs nginx with unicorn in front of puppetmaster
# tested only on centos 7

class puppet::unicorn () {
  include nginx
  # install unicorn
  package {['unicorn', 'rack']:
    ensure    => 'latest',
    provider  => 'gem',
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
  }
  exec{'systemd-reload':
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
    notify      => Service['unicorn-puppetmaster'],
  }
  unless defined(Service['unicorn-puppetmaster']) {
    service{'unicorn-puppetmaster':
      ensure  => 'running',
      enable  => 'enable',
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
      enable  => 'enable',
    }
  }
}

