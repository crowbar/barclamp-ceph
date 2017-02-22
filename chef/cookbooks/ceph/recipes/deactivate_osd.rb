unless node["roles"].include?("ceph-osd")
  node["ceph"]["services"]["osd"].each do |name|
    service name do
      action [:stop, :disable]
    end
  end
  node["ceph"]["services"].delete("osd")
  node.delete("ceph") if node["ceph"]["services"].empty?
  node.save
end
