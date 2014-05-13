# -*- encoding : utf-8 -*-
name "ceph-glance"
description "Ceph Glance Client"
run_list(
        'recipe[ceph::glance]'
)
