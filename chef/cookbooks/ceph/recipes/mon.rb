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

if master
  # resize the cluster if needed
#  number_of_osds = search("node", "ceph_osd_enabled:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc").size
  max_osds = get_max_osds()
  current_osds = get_num_running_osds()

  Chef::Log.info("max_osds: #{max_osds}, current_osds: #{current_osds}")

  if max_osds != 0 &&  max_osds <= current_osds

    execute "Set the number of OSDs to #{max_osds+1}" do
      command "/usr/bin/ceph osd setmaxosd #{max_osds + 1}"
      action :run
    end

    execute "Load a new crushmap for all the OSDs" do
      command "/usr/bin/osdmaptool --createsimple #{max_osds} --clobber /tmp/osdmap.junk --export-crush /tmp/crush.new && /usr/bin/ceph osd setcrushmap -i /tmp/crush.new"
      action :run
    end
  end
end

service "mon.#{my_index}" do
  supports :restart => true
  start_command "/etc/init.d/ceph start mon.#{my_index}"
  stop_command "/etc/init.d/ceph stop mon.#{my_index}"
  restart_command "/etc/init.d/ceph restart mon.#{my_index}"
  action [:start]
end
