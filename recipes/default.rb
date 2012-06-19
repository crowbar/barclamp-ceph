
#apt_repository "ceph" do
#  uri "http://ceph.newdream.net/debian/"
#  distribution node['lsb']['codename'] 
#  components ["main"]
#  key "https://raw.github.com/ceph/ceph/master/keys/release.asc"
#  action :add
#end

%w(ceph).each do |pkg|
  package pkg do
    action :upgrade
  end
end


mon_nodes = get_mon_nodes()

ceph_config "/etc/ceph/ceph.conf" do
    monitors mon_nodes
    clustername node[:ceph][:clustername]
end
