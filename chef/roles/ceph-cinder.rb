# -*- encoding : utf-8 -*-
name "ceph-cinder"
description "Ceph Cinder Client"
run_list(
        'recipe[ceph::cinder]'
)
