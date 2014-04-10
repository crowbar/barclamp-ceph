unless node["roles"].include?("ceph-osd")
  node["ceph"]["platform"]["osd"]["services"].each do |name|
    service name do
      action [:stop, :disable]
    end
  end
  node["ceph"]["services"].delete("osd")
  node.delete("ceph") if node["ceph"]["services"].empty?
  node.save
end
