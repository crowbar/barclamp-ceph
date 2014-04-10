unless node["roles"].include?("ceph-mon")
  node["ceph"]["platform"]["mon"]["services"].each do |name|
    service name do
      action [:stop, :disable]
    end
  end
  node["ceph"]["services"].delete("mon")
  node.delete("ceph") if node["ceph"]["services"].empty?
  node.save
end
