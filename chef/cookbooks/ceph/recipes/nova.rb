include_recipe "ceph::keyring"

case node[:platform]
when "suse"
  package "python-ceph"
  package "qemu-block-rbd" do
    action :install
    only_if { node[:platform_version].to_f >= 12.0 }
  end
end

# TODO cluster name
cluster = 'ceph'

cinder_controller = search(:node, "roles:cinder-controller")
if cinder_controller.length > 0
  cinder_pools = []
  cinder_controller[0][:cinder][:volumes].each do |volume|
    next unless (volume['backend_driver'] == "rbd") && volume['rbd']['use_crowbar']
    cinder_pools << volume[:rbd][:pool]
  end

  nova_uuid = node["ceph"]["config"]["fsid"]
  nova_user = 'nova'

  if nova_uuid.nil? || nova_uuid.empty?
    mons = get_mon_nodes("ceph_admin-secret:*")
    if mons.empty? then
      Chef::Log.fatal("No ceph-mon found")
      raise "No ceph-mon found"
    end

    nova_uuid = mons[0]["ceph"]["config"]["fsid"]
  end

  allow_pools = cinder_pools.map{|p| "allow rwx pool=#{p}"}.join(", ")
  ceph_caps = { 'mon' => 'allow r', 'osd' => "allow class-read object_prefix rbd_children, #{allow_pools}" }

  ceph_client nova_user do
    caps ceph_caps
    keyname "client.#{nova_user}"
    filename "/etc/ceph/ceph.client.#{nova_user}.keyring"
    owner "root"
    group node[:nova][:group]
    mode 0640
  end

  secret_file_path = "/etc/ceph/ceph-secret.xml"

  file secret_file_path do
    owner "root"
    group "root"
    mode "0640"
    content "<secret ephemeral='no' private='no'> <uuid>#{nova_uuid}</uuid><usage type='ceph'> <name>client.#{nova_user} secret</name> </usage> </secret>"
  end #file secret_file_path

  ruby_block "save nova key as libvirt secret" do
    block do
      if system("virsh hostname &> /dev/null")
        client_key = %x[ ceph auth get-key client.'#{nova_user}' ]
        raise 'getting nova client key failed' unless $?.exitstatus == 0

        # Just as a friendly reminder: It is okay that this command fails and
        # spits an error message. The error message contains the info we're looking
        # for
        secret_out = %x[ LC_ALL=C virsh secret-define --file '#{secret_file_path}' 2>&1 ]
        secret_uuid = secret_out[/(\S{8}-\S{4}-\S{4}-\S{4}-\S{12})/, 1]

        unless secret_uuid.empty?
          %x[ virsh secret-set-value --secret '#{secret_uuid}' --base64 '#{client_key}' ]
          raise 'importing secret file failed' unless $?.exitstatus == 0
        end
      end
    end
  end

  if node['ceph']['nova-user'] != nova_user || node['ceph']['nova-uuid'] != nova_uuid
    node['ceph']['nova-user'] = nova_user
    node['ceph']['nova-uuid'] = nova_uuid
    node.save
  end
end
