# -*- encoding : utf-8 -*-
name "ceph-osd"
description "Ceph Object Storage Device"
run_list(
        'recipe[ceph::osd]'
)
