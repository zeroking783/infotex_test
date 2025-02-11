Vagrant.configure("2") do |config|

    # Использую самый популярный debian образ с Vagrant Box Catalog, как указано в ТЗ
    config.vm.box = "file://.vagrant/a7e0500d-dbff-11ef-b23b-1e508bf425ce"
  
    config.vm.define "sqlite3" do |test_server|
    
        # Делаю машину доступной в приватной сети, чтобы я мог на ней в будущем тестировать playbook
        test_server.vm.network "private_network", ip: "192.168.56.101"
    end
end