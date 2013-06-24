#!/bin/sh
ii=310
ceph mon getmap -o monmap
ceph-osd -c /etc/ceph/ceph.conf --monmap monmap -i $ii --mkfs --mkkey
ceph auth add osd.$ii osd 'allow *' mon 'allow rwx' -i /etc/ceph/keyring.osd.$ii
/etc/init.d/ceph start osd.$ii
ceph osd in $ii
