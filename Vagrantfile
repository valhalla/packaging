# -*- mode: ruby -*-
# vi: set ft=ruby :

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "ubuntu/trusty32"

  # The time in seconds that Vagrant will wait for the machine to boot and be
  # accessible. By default this is 300 seconds.
  config.vm.boot_timeout = 900

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", 6500]
    vb.customize ["modifyvm", :id, "--cpus", 1]
    vb.customize ["modifyvm", :id, "--hwvirtex", "off"]
    vb.customize ["modifyvm", :id, "--nictype1", "Am79C973"]
    vb.customize ["modifyvm", :id, "--nictype2", "Am79C973"]
  #  vb.customize ["modifyvm", :id, "--vtxvpid", "off"]
  #  vb.customize ["modifyvm", :id, "--vtxux", "off"]
  #  vb.customize ["modifyvm", :id, "--pae", "off"]
  end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Define a Vagrant Push strategy for pushing to Atlas. Other push strategies
  # such as FTP and Heroku are also available. See the documentation at
  # https://docs.vagrantup.com/v2/push/atlas.html for more information.
  # config.push.define "atlas" do |push|
  #   push.app = "YOUR_ATLAS_USERNAME/YOUR_APPLICATION_NAME"
  # end


  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  config.vm.network "private_network", ip: "192.168.35.25", auto_config: false

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  config.vm.provision "shell", inline: <<-SHELL
    ### Create configuration for host-only adapter. In my case eth1
    # Clear previous setting
    rm -f /etc/network/interfaces.d/eth1.cfg
    # Create new setting
    echo "auto eth1" >> /etc/network/interfaces.d/eth1.cfg
    echo "iface eth1 inet static" >> /etc/network/interfaces.d/eth1.cfg
    # ip address should be the same as in a private_network
    echo "address 192.168.35.25" >> /etc/network/interfaces.d/eth1.cfg
    echo "netmask 255.255.255.0" >> /etc/network/interfaces.d/eth1.cfg
    # Restart adapter for apply new setting
    ifdown eth1 && ifup eth1

    #build valhalla
    set -e
    cd /vagrant
    sudo hooks/D10addppa
    sudo apt-get install -y dh-make dh-autoreconf bzr-builddeb pbuilder debootstrap devscripts distro-info
    sudo apt-get install -y git autoconf automake pkg-config libtool make gcc g++ lcov
    for pkg in $(grep -F Build-Depends debian/control | sed -e "s/(.*),//g" -e "s/,//g" -e "s/^.*://g"); do
  	  sudo apt-get install -y ${pkg}
    done
    cd libvalhalla
    ./autogen.sh
    ./configure CPPFLAGS="-DBOOST_SPIRIT_THREADSAFE -DBOOST_NO_CXX11_SCOPED_ENUMS"
    make -j2
  SHELL
end
