JOURNAL_SIZE = 1000

def get_osd_index(path)
  if osd_initialized?(path)
    osd_index = File.read("/#{path}/whoami").to_i
  else
    0
  end
end

def osd_initialized?(path)
  File.exist?("/#{path}/whoami")
end

def get_master_secret
  master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  
  if (master_mons.size == 0) # allow chef server to reindex my data...
    sleep 10
    master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  end

  master = master_mons.first
  
  master[:ceph][:secrets]['client.admin']
end

def get_master_mon_secret
  master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  
  if (master_mons.size == 0) # allow chef server to reindex my data...
    sleep 10
    master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  end

  master = master_mons.first
  
  master[:ceph][:secrets]['mon.']
end

def get_master_mon_fsid
  master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  
  if (master_mons.size == 0) # allow chef server to reindex my data...
    sleep 10
    master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  end

  master = master_mons.first
  
  master[:ceph][:monfsid]
end

def is_crowbar?()
  return defined?(Chef::Recipe::Barclamp) != nil
end

def get_mon_nodes()
  if is_crowbar?
    mon_nodes = []
    mon_names = node['ceph']['monitors'] || []
    mon_names.each do |n|
      monitor = {}
      search(:node, "name:#{n}") do |match|
        monitor[:address] = Chef::Recipe::Barclamp::Inventory.get_network_by_type(match, "admin").address
        monitor[:name] = match[:hostname]
      end
      mon_nodes << monitor
    end
  end
  return mon_nodes
end

def get_osd_path(device)
  Chef::Log.info("Device to find id: #{device}")

  if File.exist?("#{device}")
    id_ser = %x( /sbin/udevadm info --query=env --name #{device} 2>/dev/null | grep ID_SERIAL= )
    id = id_ser.split('=')[1].strip

    id_part = %x{ udevadm info --query=env --name #{device} | grep PART_ENTRY_NUMBER }
    part = id_part.empty? ? "" : "-#{id_part.split('=')[1].strip}"

    osd_path = "/var/lib/ceph/osd/#{node[:ceph][:clustername]}-#{id}#{part}"
    return osd_path
  else
    nil
  end
end

def get_local_osds()
  if is_crowbar?
    osds = []
    if local_osds?
      devices = node[:ceph][:devices] || []
      devices.each do |device|
        if osd_initialized?(get_osd_path(device))
          osd = {}
          osd[:index] = get_osd_index(get_osd_path(device))
          osd[:hostname] = %x{hostname}.strip
          osd[:data] = get_osd_path(device)
          osds << osd
        end
      end
    end
  end
  return osds
end

def get_max_osds()
  maxosds = %x{ceph osd dump | grep max_osd}.split[1].to_i
end

def get_num_running_osds()
  %x{ceph osd stat}.split[1].to_i
end

def local_osds?()
  node[:ceph][:osd][:enabled]
end

def num_osds_from_db()
  if node[:ceph][:osds]
    nodes = node[:ceph][:osds].size
    nodes *= node[:ceph][:devices].size if node[:ceph][:devices]
  else
    return 0
  end
end

def ceph_running?
  %x{ps aux | grep ceph | wc -l}.to_i > 1
end
