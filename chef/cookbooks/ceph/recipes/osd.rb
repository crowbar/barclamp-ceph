# initialize ceph nodes

# we need a master, and our mon-cluster needs to work...
master_mons = search("node", "roles:ceph-mon-master AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []

if master_mons.size == 0
  Chef::Log.error("No master server found in ceph cluster #{node[:ceph][:clustername]} - not initializing/configuring OSDs")
  return 
end

include_recipe "ceph::default"
package "util-linux"

node[:ceph][:osd][:enabled] = true

c = ceph_keyring "client.admin" do
  secret get_master_secret
  action [:create, :add] 
end

# search for possible OSDs, labeled 
devices = node[:ceph][:devices]
Chef::Log.info "Devices: #{devices.join(',')}"

# exclude non-exixting devices per-node
wrong_devs = []
devices.each do |device|
  next if File.exist?(device)
  Chef::Log.info("Device #{device} doesn't exist")
  wrong_devs << device
end
wrong_devs.each { |wd| devices.delete(wd) }

devices.each do |device|
  osd_path = get_default_osd_path(device)
  index = get_osd_index_from_db(device).to_i
  Chef::Log.info("OSD Index from DB: #{index}")

  execute "kill processes accessing #{device}, if an OSD should be deployed" do
    command "( kill -9 $(lsof -t #{device}); wait 3; exit 0)"
    not_if { osd_initialized?(index) }
  end

  execute "unmount #{device}" do
    command "(umount #{device}; exit 0)"
    not_if { osd_initialized?(index) }
  end
 
  execute "make xfs filesystem on #{device}" do
    command "mkfs.xfs -f #{device}"
    not_if { osd_initialized?(index) }
  end

  directory osd_path do
    owner "root"
    group "root"
    mode "0755"
    recursive true
    action :create
  end
  
  mount osd_path do 
    device device
    fstype "xfs"
    options "noatime"
    action [:enable, :mount]
    not_if mounted
  end
    
  ceph_osd "Initializing new osd on #{device} " do
    path osd_path
    device device
    osd_index index
    action [:initialize]
    not_if { osd_initialized?(index) }
  end

  ceph_osd "Starting the osd from #{index}" do
    path osd_path
    osd_index index
    action [:start]
  end
end if devices

