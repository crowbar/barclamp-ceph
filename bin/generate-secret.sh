#!/usr/bin/env bash

# need to find a better place to force the install
# of ceph-common on the admin node
apt-get -qq install ceph-common > /dev/null 2>&1

# then we generate a valid ceph auth key and strip the newline
ceph-authtool --gen-print-key | tr -d '\n'
