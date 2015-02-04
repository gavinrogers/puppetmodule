# Define: puppet::masterenv
#
# This define configures puppet master environment
#
# Parameters:
#   ['modulepath']         - The modulepath for the environment
#   ['manifest']           - The manifest for the environmen
#
# Actions:
# - Add enviroments to the puppet master
#
# Requires:
# - Inifile
#
# Sample Usage:
#   puppet::masterenv{ 'dev':
#       modulepath             => '/etc/puppet/modules'
#       manifest               => 'dev'
#   }
#
define  puppet::masterenv (
  $modulepath,
  $manifest,
  $puppet_conf = $::puppet::params::puppet_conf,
  $environments = $::puppet::master::environments,
  $environmentpath = $::puppet::master::environmentpath
) {

  case $environments {
    'directory': {
      $path = "${environmentpath}/${name}/environment.conf"
      $section = ''
      file { "${environmentpath}/${name}":
        ensure => directory,
        before => [Ini_setting["masterenvmodule${name}"],Ini_setting["masterenvmanifest${name}"]],
      }
    }
    default: {
      $path = $puppet_conf
      $section = $name
    }
  }

  Ini_setting {
      path    => $path,
      section => $section,
      require => [File[$puppet_conf], Class['puppet::master']],
      notify  => Service['httpd'],
  }

  ini_setting {
    "masterenvmodule${name}":
      ensure  => present,
      setting => 'modulepath',
      value   => $modulepath;

    "masterenvmanifest${name}":
      ensure  => present,
      setting => 'manifest',
      value   => $manifest;
  }
}
