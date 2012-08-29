JOURNAL_SIZE = 1000

def get_osd_index_from_db(device)
  if File.exist?(device)
    if node.has_key?("ceph") && node["ceph"].has_key?("osd_nodes")
      osd_index = -1
      osd_node_hash = node["ceph"]["osd_nodes"]
      osd_node_hash.each do |nodename, osd_data|
        if nodename == node.name
          osd_data.each do |id, dev|
            Chef::Log.info("id: #{id}, dev: #{dev}, device: #{device}") 
            osd_index = id if  dev == device
          end
        end
      end
      osd_index
    end
  end
end

def new_osd?(index)
  Chef::Log.info("in New OSD")
  return !system("ceph osd tree | grep -q osd.#{index}")
end

def get_master_secret
  master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  
  if (master_mons.size == 0) # allow chef server to reindex my data...
    sleep 10
    master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  end

  master = master_mons.first
  if master.has_key?("ceph") && master[:ceph].has_key?("secrets") && master[:ceph][:secrets].has_key?("client.admin") 
    master[:ceph][:secrets]['client.admin']
  else 
    nil
  end 
end

def get_master_mon_secret
  master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  
  if (master_mons.size == 0) # allow chef server to reindex my data...
    sleep 10
    master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  end

  master = master_mons.first
  if master.has_key?("ceph") && master[:ceph].has_key?("secrets") && master[:ceph][:secrets].has_key?("mon.")  
    master[:ceph][:secrets]['mon.']
  else
    nil
  end
end

def get_master_mon_fsid
  master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  
  if (master_mons.size == 0) # allow chef server to reindex my data...
    sleep 10
    master_mons = search("node", "ceph_master:true AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}", "X_CHEF_id_CHEF_X asc") || []
  end

  master = master_mons.first
  if master.has_key?("ceph") && master["ceph"].has_key?("monfsid")
    master[:ceph][:monfsid]
  else
    nil
  end
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

def get_default_osd_path(device)
  osd_index = get_osd_index_from_db(device)     
  Chef::Log.info("OSD Index: #{osd_index}")
  osd_path = "/var/lib/ceph/osd/ceph-#{osd_index}" if osd_index
end

def get_all_osds()
  osds = []
  if is_crowbar?
       
    osd_nodes = node["ceph"]["osd_nodes"] || {}
    osd_nodes.sort_by { |node,osd_data| node }.each do |node,osd_data|
      port_counter = 6799
      cluster_addr = ''
      public_addr = ''
      search(:node, "name:#{node}") do |match|
        public_addr = Chef::Recipe::Barclamp::Inventory.get_network_by_type(match, "admin").address
        cluster_addr = Chef::Recipe::Barclamp::Inventory.get_network_by_type(match, "storage").address
      end

      Chef::Log.info("Node: #{node}")
      Chef::Log.info("Data: #{osd_data.inspect}") 
      osd_data.sort_by { |index, device| index }.each do |index, device|
        osd = {}
        osd[:hostname]= node.split('.')[0]
        osd[:device] = device 
        osd[:index] = index
        osd[:cluster_addr] = cluster_addr
        osd[:cluster_port] = (port_counter += 1)
        osd[:public_addr] = public_addr
        osd[:public_port] = (port_counter += 1)
        Chef::Log.info("OSD data: #{osd[:hostname]}, OSD.#{osd[:index]}, #{osd[:device]}, #{osd[:cluster_port]}, #{osd[:public_port]}" )
        Chef::Log.info("OSD data: #{osd.inspect}" )
        osds << osd
      end 
    end
  end
  Chef::Log.info("#{osds.inspect}") 
  return osds
end    

def osd_in_crush?(index)
  Chef::Log.info("osd in crush: #{index}")
   %x{rm -f /tmp/osd-init/*}
   %x{/usr/bin/ceph osd getmap -o /tmp/osd-init/osdmap}
   %x{/usr/bin/osdmaptool /tmp/osd-init/osdmap --export-crush /tmp/osd-init/crush}  
   system("/usr/bin/crushtool -d /tmp/osd-init/crush | grep -q osd.#{index}")
end
