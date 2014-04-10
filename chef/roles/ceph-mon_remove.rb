name "ceph-mon_remove"
description "Deactivate Ceph Monitor Role services"
run_list(
  "recipe[ceph::deactivate_mon]"
)
default_attributes()
override_attributes()
