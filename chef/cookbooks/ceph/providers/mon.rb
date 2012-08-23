action :create do
  directory "/var/lib/ceph/mon/ceph-#{@new_resource.index}" do
    owner "root"
    group "root"
    mode "0755"
    recursive true
    action :create
  end

  if node[:ceph][:master]
    ceph_keyring "client.admin" do
      action [:create, :add, :store]
      not_if { IO::File.exist?("/etc/ceph/client.admin.keyring") and get_master_secret() } 
    end
  end
end

action :initialize do 
  i = @new_resource.index

  Chef::Log.info("mon::initialize")
  if node[:ceph][:master]
    Chef::Log.info("mon::initialize master")
    ceph_keyring "mon.#{i}" do
      action [:create, :add, :store]
      keyname "mon." # WTF?
    end
  else
    ceph_keyring "mon.#{i}" do
      Chef::Log.info("mon::initialize non master")
      secret get_master_mon_secret
      action [:create, :add, :store]
      keyname "mon." # WTF?
    end
  end    

  ceph_keyring "mon.#{i}" do
    action :add
    secret get_master_secret
    keyname "client.admin"
    authtool_options "--set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'"
  end

  temp_mon_init_path = %x{/bin/mktemp /tmp/mon-init-XXXXXXXXXX}.strip

  # either we are the first mon (master), either we are a backup mon (not master)
  if node[:ceph][:master]
    execute "CEPH MASTER INIT: Preparing the monmap" do
      command "/sbin/mkcephfs -d #{temp_mon_init_path} -c /etc/ceph/ceph.conf --prepare-monmap"
    end

    execute "CEPH MASTER INIT: prepare the osdmap" do
      command "/usr/bin/osdmaptool --create_from_conf  -c /etc/ceph/ceph.conf --clobber #{temp_mon_init_path}/osdmap.junk --export-crush #{temp_mon_init_path}/crush.new"
    end

    ruby_block "Store fsid for the master mon" do
      block do
        node.set[:ceph][:monfsid] = `monmaptool --print #{temp_mon_init_path}/monmap  | grep fsid | cut -d' ' -f2`.strip
        node.save
      end
      action :create
    end

    execute "Prepare the monitors file structure" do
      command "/usr/bin/ceph-mon -c /etc/ceph/ceph.conf --mkfs -i #{i} --monmap #{temp_mon_init_path}/monmap --osdmap #{temp_mon_init_path}/osdmap.junk  -k /etc/ceph/mon.#{i}.keyring"
      action :run
    end
  else
    # not master
    monfsid = get_master_mon_fsid
    
    execute "Prepare the monitors file structure" do
      command "/usr/bin/ceph-mon -c /etc/ceph/ceph.conf --mkfs -i #{i} --fsid '#{monfsid}' -k /etc/ceph/mon.#{i}.keyring"
      action :run
    end

  end

end

action :set_all_permissions do
  # setting all the capabilities for the osds and mdss
  mdss = search("node", "ceph_mds_enabled:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []

  mdss.each do |mds|
    execute "Adding #{mds} as an MDS to the monitor" do
      command "/usr/bin/ceph-authtool -n mds.#{mds[:ceph][:mds][:index]} --add-key #{mds[:ceph][:mds][:secret]} /etc/ceph/keyring.mon  --cap mon 'allow rwx' --cap osd 'allow *' --cap mds 'allow'"
      action :run
      only_if mds.ceph.mds.attribute?(:secret)
    end    
  end

#FIXME: what should this be good for?
  osds = search("node", "ceph_osd_enabled:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  osds.each do |osd|
    execute "Adding #{osd} as an OSD to the monitor" do
      command "/usr/bin/ceph-authtool -n osd.#{osd[:ceph][:osd][:index]} --add-key #{osd[:ceph][:osd][:secret]} /etc/ceph/keyring.mon  --cap mon 'allow rwx' --cap osd 'allow *'"
      action :run
      only_if { osd.ceph.osd.attribute?(:secret) }
    end    
  end
end
