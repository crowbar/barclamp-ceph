# OSD provider

action :initialize do
  b = ruby_block "Determine a new index for the OSD" do
    block do
      node[:ceph][:last_osd_index] = %x(/usr/bin/ceph osd create).strip.to_i
      node.save
    end
    action :nothing
  end

  b.run_action(:create)

  osd_index = node[:ceph][:last_osd_index]
  osd_path = @new_resource.path
  host = @new_resource.host || node[:ceph][:host] || node[:hostname]
  rack = @new_resource.rack || node[:ceph][:rack] || "rack-001"

  node.set[:ceph][:osd]["#{osd_index}"] = {"#{@new_resource.device}" => @new_resource.path}
  journal_location = "/var/lib/ceph/osdjournals/#{osd_index}/journal"
  node.set[:ceph][:osd]["#{osd_index}"]["journal"] = journal_location

  directory  "/var/lib/ceph/osdjournals/#{osd_index}" do
    owner "root"
    group "root"
    mode "0755"
    recursive true
    action :create
  end

  execute "Extract the monmap" do
    command "/usr/bin/ceph mon getmap -o /etc/ceph/monmap"
    action :run
  end

  execute "Create the fs for osd.#{osd_index}" do
    command "/usr/bin/ceph-osd -i #{osd_index} -c /dev/null --monmap /etc/ceph/monmap --osd-data=#{osd_path} --osd-journal=#{journal_location} --osd-journal-size=#{JOURNAL_SIZE} --mkfs --mkjournal"
    action :run
  end
  
  ceph_keyring "osd.#{osd_index}" do
    action [:create, :add, :store]
  end

  execute "Change the mon authentication to allow osd.#{osd_index}" do
    command "/usr/bin/ceph auth add osd.#{osd_index} osd 'allow *' mon 'allow rwx' -i /etc/ceph/osd.#{osd_index}.keyring"
    action :run
  end

  mon_nodes = get_mon_nodes()
  osds = get_local_osds()

  osds += [{:index => osd_index,
           :journal => journal_location,
           :journal_size => JOURNAL_SIZE,
           :data => osd_path}]

  ceph_config "/etc/ceph/ceph.conf" do
    monitors mon_nodes
    osd_data osds
  end

#FIXME: I'll remove this, because I'm not sure wether it's needed at all
#  execute "Add one osd to the maxosd if maxosd <= osd_index" do
#    Chef::Log.info("get_max_osds: #{get_max_osds}, osd_index: #{osd_index}")
#    command "ceph osd setmaxosd $(($(ceph osd getmaxosd | cut -d' ' -f3)+1))" # or should we set osd_index + 1?
#    action :run
#    only_if { get_max_osds() <= get_num_running_osds }
#  end

  execute "Add the OSD to the crushmap" do
    command "/usr/bin/ceph osd crush set #{osd_index} osd.#{osd_index} 1 pool=default rack=#{rack} host=#{host}"
    action :run
  end
end

action :start do
  osd_path = @new_resource.path
  index = get_osd_index osd_path

  service "osd.#{index}" do
    service_name "ceph"
    supports :restart => true
    start_command "/etc/init.d/ceph start osd#{index}"
    stop_command "/etc/init.d/ceph stop osd#{index}"
    restart_command "/etc/init.d/ceph restart osd#{index}"
    action [:enable, :start]
  end
end
