name "ceph-mon-master"
description "Ceph monitor master node"
run_list(
         'recipe[ceph::mon]'
         )
