include_recipe "ceph::default"
include_recipe "ceph::conf"

node['ceph']['radosgw']['packages'].each do |pck|
  package pck
end

hostname = node['hostname']

directory "/var/run/ceph-radosgw" do
  owner node[:apache][:user]
  group node[:apache][:group]
end

file "/var/log/ceph/radosgw.log" do
  owner node[:apache][:user]
  group node[:apache][:group]
end

if !::File.exist?("/var/lib/ceph/radosgw/ceph-radosgw.#{hostname}/done")

  include_recipe "ceph::radosgw_apache2"

  ceph_client 'radosgw' do
    caps('mon' => 'allow rw', 'osd' => 'allow rwx')
    group "www"
  end

  directory "/var/lib/ceph/radosgw/ceph-radosgw.#{hostname}" do
    recursive true
  end

  file "/var/lib/ceph/radosgw/ceph-radosgw.#{hostname}/done" do
    action :create
  end

  service 'radosgw' do
    service_name node['ceph']['radosgw']['service_name']
    supports :restart => true
    action [:enable, :start]
  end
else
  Log.info('Rados Gateway already deployed')
end
