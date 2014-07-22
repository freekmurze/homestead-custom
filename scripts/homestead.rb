class Homestead
  def Homestead.configure(config, settings)
    # Configure The Box
    config.vm.box = "freekmurze/homestead-custom"
    config.vm.hostname = "homestead"

    # Configure A Private Network IP
    config.vm.network :private_network, ip: settings["ip"] ||= "192.168.10.10"
    
    # SPATIE-modification use public network
    config.vm.network :public_network, ip: settings["public_ip"], bridge: 'en0: Ethernet'

    # Configure A Few VirtualBox Settings
    config.vm.provider "virtualbox" do |vb|
      vb.customize ["modifyvm", :id, "--memory", settings["memory"] ||= "2048"]
      vb.customize ["modifyvm", :id, "--cpus", settings["cpus"] ||= "1"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end

    # Configure Port Forwarding To The Box
    config.vm.network "forwarded_port", guest: 80, host: 8000
    config.vm.network "forwarded_port", guest: 3306, host: 33060
    config.vm.network "forwarded_port", guest: 5432, host: 54320

    # Configure The Public Key For SSH Access
    config.vm.provision "shell" do |s|
      s.inline = "echo $1 | tee -a /home/vagrant/.ssh/authorized_keys"
      s.args = [File.read(File.expand_path(settings["authorize"]))]
    end

    # Copy The SSH Private Keys To The Box
    settings["keys"].each do |key|
      config.vm.provision "shell" do |s|
        s.privileged = false
        s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
        s.args = [File.read(File.expand_path(key)), key.split('/').last]
      end
    end
    
     # SPATIE modification: Copy The SSH config file  To The Box
     config.vm.provision "shell" do |s|
       s.privileged = false
       s.inline = "echo \"$1\" > /home/vagrant/.ssh/config"
       s.args = [File.read(File.expand_path('~/.ssh/config'))]
     end
    
    # SPATIE modification: enable ssh forward
    config.ssh.forward_agent = true

    # Copy The Bash Aliases
    config.vm.provision "shell" do |s|
      s.inline = "cp /vagrant/aliases /home/vagrant/.bash_aliases"
    end

    # SPATIE-MODIFICATION: USE NFS
    # Register All Of The Configured Shared Folders
    settings["folders"].each do |folder|
    	config.vm.synced_folder folder["map"], folder["to"],
    		id: folder["map"],
		:nfs => true,
    		:mount_options => ['nolock,vers=3,udp,noatime']
    end

    # Install All The Configured Nginx Sites
    settings["sites"].each do |site|
      config.vm.provision "shell" do |s|
          s.inline = "bash /vagrant/scripts/serve.sh $1 $2"
          s.args = [site["map"], site["to"]]
      end
    end

    # Configure All Of The Server Environment Variables
    if settings.has_key?("variables")
      settings["variables"].each do |var|
        config.vm.provision "shell" do |s|
            s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php5/fpm/php-fpm.conf && service php5-fpm restart"
            s.args = [var["key"], var["value"]]
        end
      end
    end
    
    #SPATIE-MODIFICATION: custom scripts
    config.vm.provision "shell", path: "./scripts/customizations.sh"
    
  end
end
