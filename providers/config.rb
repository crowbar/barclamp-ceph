action :create do

  search_restrictions = " AND ceph_clustername:#{node['ceph']['clustername']} AND chef_environment:#{node.chef_environment}"
  search_myself = " OR hostname:#{node[:hostname]}"

  mdss = search("node", "(ceph_mds_enabled:true" + (@new_resource.i_am_a_mds ? search_myself : "") + ")" + search_restrictions, "X_CHEF_id_CHEF_X asc")
  osd_names = node["ceph"]["elements"]["ceph-store"] || [] 
  osds = []
  osd_names.each { |osd| osds += search(:node, "name:#{osd}") }

  template new_resource.config_file do
          source          "ceph.conf"
          mode            "0644"
          action          :create
          variables( 
            :mdss => mdss,
            :osds => osds,
            :extra_osds_data => new_resource.osd_data,
            :monitors => new_resource.monitors,
            :clustername => new_resource.clustername
          )
  end
end
