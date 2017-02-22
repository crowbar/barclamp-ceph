case node["platform"]
when "suse"
  default["ceph"]["services"] = {
    "mon" => ["ceph"],
    "osd" => ["ceph"]
  }
end
