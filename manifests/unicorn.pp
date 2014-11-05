# this class installs nginx with unicorn infront of puppetmaster
class puppet::unicorn () {
  include nginx
#  nginx::resource::vhost {'puppetmaster':
#    www_root => '/var/empty',
#  }
}
