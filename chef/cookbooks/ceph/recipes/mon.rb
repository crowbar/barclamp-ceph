# This recipe creates a monitor cluster
#
# You should never change the mon default path or
# the keyring path.
# Don't change the cluster name either
# Default path for mon data: /var/lib/ceph/mon/$cluster-$id/
#   which will be /var/lib/ceph/mon/ceph-`hostname`/
#   This path is used by upstart. If changed, upstart won't
#   start the monitor
# The keyring files are created using the following pattern:
#  /etc/ceph/$cluster.client.$name.keyring
#  e.g. /etc/ceph/ceph.client.admin.keyring
#  The bootstrap-osd and bootstrap-mds keyring are a bit
#  different and are created in
#  /var/lib/ceph/bootstrap-{osd,mds}/ceph.keyring

include_recipe "ceph::default"
include_recipe "ceph::conf"

service_type = node["ceph"]["mon"]["init_style"]

directory "/var/run/ceph" do
  owner "root"
  group "root"
  mode 00755
  recursive true
  action :create
end

directory "/var/log/ceph" do
  owner "root"
  group "root"
  mode 00755
  recursive true
  action :create
end

directory "/var/lib/ceph/mon/ceph-#{node["hostname"]}" do
  owner "root"
  group "root"
  mode 00755
  recursive true
  action :create
end

# TODO cluster name
cluster = 'ceph'

unless File.exists?("/var/lib/ceph/mon/ceph-#{node["hostname"]}/done")
  keyring = "#{Chef::Config[:file_cache_path]}/#{cluster}-#{node['hostname']}.mon.keyring"

  monitor_secret = if node['ceph']['encrypted_data_bags']
    secret = Chef::EncryptedDataBagItem.load_secret(node["ceph"]["mon"]["secret_file"])
    Chef::EncryptedDataBagItem.load("ceph", "mon", secret)["secret"]
  else
    node["ceph"]["monitor-secret"]
  end

  execute "format as keyring" do
    command "ceph-authtool '#{keyring}' --create-keyring --name=mon. --add-key='#{monitor_secret}' --cap mon 'allow *'"
    creates "#{Chef::Config[:file_cache_path]}/#{cluster}-#{node['hostname']}.mon.keyring"
  end

  admin_secret = node["ceph"]["admin-secret"]

  execute "create admin keyring" do
    command "ceph-authtool --create-keyring /etc/ceph/keyring --name=client.admin --add-key='#{admin_secret}'"
  end

  execute "add admin key to mon.keyring" do
    command "ceph-authtool '#{keyring}' --name=client.admin --add-key='#{admin_secret}' --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'"
  end

  execute 'ceph-mon mkfs' do
    command "ceph-mon --mkfs -i #{node['hostname']} --keyring '#{keyring}'"
  end

  ruby_block "finalise" do
    block do
      ["done", service_type].each do |ack|
        File.open("/var/lib/ceph/mon/ceph-#{node["hostname"]}/#{ack}", "w").close()
      end
    end
  end
end

if service_type == "upstart"
  service "ceph-mon" do
    provider Chef::Provider::Service::Upstart
    action :enable
  end
  service "ceph-mon-all" do
    provider Chef::Provider::Service::Upstart
    supports :status => true
    action [ :enable, :start ]
  end
end

service "ceph_mon" do
  case service_type
  when "upstart"
    service_name "ceph-mon-all-starter"
    provider Chef::Provider::Service::Upstart
  else
    service_name "ceph"
  end
  supports :restart => true, :status => true
  action [ :enable, :start ]
end

get_mon_addresses().each do |addr|
  execute "peer #{addr}" do
    command "ceph --admin-daemon '/var/run/ceph/ceph-mon.#{node['hostname']}.asok' add_bootstrap_peer_hint #{addr}"
    ignore_failure true
  end
end

# The key is going to be automatically
# created,
# We store it when it is created
unless node['ceph']['encrypted_data_bags']
  ruby_block "get osd-bootstrap keyring" do
    block do
      run_out = ""
      while run_out.empty?
        #centos has no mixlib available
        #don't see any reasons why we can't use generic ruby here
        run_out = `ceph auth get-or-create-key client.bootstrap-osd 2>/dev/null`.strip
      end
      node.normal['ceph']['bootstrap_osd_key'] = run_out
      node.save
    end
    not_if { node['ceph']['bootstrap_osd_key'] }
  end
end
