# makes the node a Ceph monitor, if it is in the monitor list

master = node[:roles].include? "ceph-mon-master"
Chef::Log.info("Master? #{master}")
node.set[:ceph][:master] = master
node.save

include_recipe "ceph::default"

my_index = "#{node['hostname']}-#{node['ceph']['clustername']}"

ceph_mon "creating mon" do
  index my_index
  action :create
end 

ceph_mon "Initializing the monitor FS" do
  index my_index
  action :initialize
  not_if "test -f /var/lib/ceph/mon/ceph-#{my_index}/magic"
end

service "mon.#{my_index}" do
  service_name "ceph"
  supports :restart => true
  start_command "/etc/init.d/ceph start mon.#{my_index}"
  stop_command "/etc/init.d/ceph stop mon.#{my_index}"
  restart_command "/etc/init.d/ceph restart mon.#{my_index}"
  action [:enable, :start]
end
