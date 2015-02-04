require 'beaker-rspec'

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  # Enable colour
  c.tty = true

  # This is where we 'setup' the nodes before running our tests
  c.before :suite do
    hosts.each do |host|
      # Install puppet
      install_puppet()
      osfamily = on(host, facter('osfamily')).stdout.strip
      osrelease = on(host, facter('operatingsystemmajrelease')).stdout.strip

      puppet_module_install(:source => proj_root, :module_name => 'puppet')
      # Install dependencies from Modulefile
      shell("echo '127.0.0.1 master.test.local' >> /etc/hosts")
      shell('hostname master.test.local')
      on host, puppet('module', 'install', 'puppetlabs-inifile'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module', 'install', 'puppetlabs-apache'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module', 'install', 'puppetlabs-puppetdb'), { :acceptable_exit_codes => [0,1] }
      on host, puppet('module', 'install', 'puppetlabs-stdlib'), { :acceptable_exit_codes => [0,1] }
      if osfamily == 'Debian'
        shell('puppet module install puppetlabs-apt')
      end
      # puppetlabs-apache requires EPEL for mod_passenger
      if osfamily == 'RedHat'
        on host, puppet('module', 'install', 'stahnma-epel'), { :acceptable_exit_codes => [0,1] }
        on host, puppet('apply', '-e', '"class {epel:}"'), { :acceptable_exit_codes => [0] }
        shell("rpm -iv http://yum.theforeman.org/releases/latest/el#{osrelease}/x86_64/foreman-release.rpm")
      end
    end
  end
end
