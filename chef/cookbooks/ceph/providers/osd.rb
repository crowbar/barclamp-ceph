# OSD provider

action :initialize do
  b = ruby_block "Determine a new index for the OSD" do
    block do
      %x(/usr/bin/ceph osd create)
    end
    action :nothing
  end

  directory "/tmp/osd-init" do
    owner "root"
    group "root"
    mode "0755"
    action :create
  end


  osd_path = @new_resource.path
  host = @new_resource.host || node[:ceph][:host] || node[:hostname]
  rack = @new_resource.rack || node[:ceph][:rack] || "unknownrack"
  osd_index = @new_resource.osd_index
  newosd = new_osd?(@new_resource.osd_index)

  while newosd 
    b.run_action(:create) 
    newosd = new_osd?(osd_index)
  end

  journal_location = "/var/lib/ceph/osdjournals/#{osd_index}/journal"

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

  execute "Add OSD.#{osd_index} to crushmap" do
    command "/usr/bin/ceph osd crush set #{osd_index} osd.#{osd_index} 1 pool=default rack=#{rack} host=#{host}"
    action :run
    not_if { osd_in_crush?(osd_index) }
  end
end

action :start do
  osd_path = @new_resource.path
  index = @new_resource.osd_index

  service "osd.#{index}" do
    service_name "ceph"
    supports :restart => true
    start_command "/etc/init.d/ceph start osd#{index}"
    action [:enable, :start]
  end
end
