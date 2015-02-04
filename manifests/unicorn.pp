# Class: puppet::unicorn
#
# Parameters:
#  ['listen_address']     - IP for binding the webserver, defaults to *
#  ['puppet_proxy_port']  - The port for the virtual host
#  ['disable_ssl']        - Disables SSL on the webserver. usefull if you use this master behind a loadbalancer. currently only supported by nginx, defaults to undef
#  ['backup_upstream']    - specify another puppet master as fallback. currently only supported by nginx
#  ['unicorn_package']    - package name of a unicorn rpm. if provided we install it, otherwise we built it via gem/gcc
#  ['unicorn_path']       - custom path to the unicorn binary
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
  $certname,
  $puppet_conf,
  $puppet_ssldir,
  $dns_alt_names,
  $listen_address,
  $puppet_proxy_port,
  $disable_ssl,
  $backup_upstream,
  $unicorn_package,
  $unicorn_path,
){
  include nginx

  # if this is provided we install the package from the repo, otherwise we build unicorn from scratch
  if $unicorn_package {
    package {$unicorn_package:
      ensure  => 'latest',
    }
  } else {
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
    }
  }
  file {'unicorn-conf':
    path    => '/etc/puppet/unicorn.conf',
    source  => 'puppet:///modules/puppet/unicorn.conf',
  } ->
  file {'copy-config':
    path    => '/etc/puppet/config.ru',
    source  => '/usr/share/puppet/ext/rack/config.ru',
  } ->

  file {'unicorn-service':
    path    => '/usr/lib/systemd/system/unicorn-puppetmaster.service',
    content => template('puppet/unicorn-puppetmaster.service'),
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
    }
  }
  # update SELinux
  if $::selinux_config_mode == 'enforcing' {
    class { selinux:
      mode  => 'enforcing'
    }
    selinux::module{ 'nginx':
      ensure  => 'present',
      content =>  template('puppet/unicorn_selinux_template'),
    }
  }

  # first we need to generate the cert
  # Clean the installed certs out ifrst
  $crt_clean_cmd  = "puppet cert clean ${certname}"
  # I would have preferred to use puppet cert generate, but it does not
  # return the corret exit code on some versions of puppet
  $crt_gen_cmd   = "puppet certificate --ca-location=local --dns_alt_names=$dns_alt_names generate ${certname}"
  # I am using the sign command here b/c AFAICT, the sign command for certificate
  # does not work
  $crt_sign_cmd  = "puppet cert sign --allow-dns-alt-names ${certname}"
  # find is required to move the cert into the certs directory which is
  # where it needs to be for puppetdb to find it
  $cert_find_cmd = "puppet certificate --ca-location=local find ${certname}"

  exec { 'Certificate_Check':
    command   => "${crt_clean_cmd} ; ${crt_gen_cmd} && ${crt_sign_cmd} && ${cert_find_cmd}",
    unless    => "/bin/ls ${puppet_ssldir}/certs/${certname}.pem",
    path      => '/usr/bin:/usr/local/bin',
    logoutput => on_failure,
    require   => File[$puppet_conf]
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

