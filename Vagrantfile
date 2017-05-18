Vagrant.configure(2) do |config|

   config.vm.define 'trident-server' do |box|
      box.vm.box = "ubu14"
      box.vm.hostname = 'empire'
      box.vm.network :private_network, ip: "192.168.33.33"
      box.vm.provider :virtualbox do |vb|
       vb.customize ["modifyvm", :id, "--memory", "1024"]
       vb.customize ["modifyvm", :id, "--cpus", "2"]
      end
      config.vm.provision "shell",  path: "provision/installTridentPosgreSQLPostfix.sh"
   end

  config.vm.define 'oauth-client' do |box|
     box.vm.box = "ubu14"
     box.vm.hostname = 'hopper'
     box.vm.network :private_network, ip: "192.168.33.22"
     box.vm.provider :virtualbox do |vb|
      vb.customize ["modifyvm", :id, "--memory", "512"]
      vb.customize ["modifyvm", :id, "--cpus", "1"]
     end
     config.vm.provision "shell", path: "provision/installOAUTH2Test.sh"
  end

end
