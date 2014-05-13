# -*- encoding : utf-8 -*-
name "ceph-mon"
description "Ceph Monitor"
run_list(
        'recipe[ceph::mon]'
)
