name "ceph-osd_remove"
description "Deactivate Ceph Osd Role services"
run_list(
  "recipe[ceph::deactivate_osd]"
)
default_attributes()
override_attributes()
