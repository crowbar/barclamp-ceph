package "ceph"

mon_nodes = get_mon_nodes()
osd_devs = get_all_osds()
Chef::Log.info("#{osd_devs.inspect}")

ceph_config "/etc/ceph/ceph.conf" do
  monitors mon_nodes
  osd_data osd_devs
  clustername node[:ceph][:clustername]
end
