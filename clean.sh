#!/bin/sh
for i in `seq 1 9`;do rm -rf /srv/ceph/osd10$i/*;done
for i in `seq 1 9`;do rm -rf /srv/ceph/osd20$i/*;done
for i in `seq 1 9`;do rm -rf /srv/ceph/osd30$i/*;done
for i in `seq 10 12`;do rm -rf /srv/ceph/osd1$i/*;done
for i in `seq 10 12`;do rm -rf /srv/ceph/osd2$i/*;done
for i in `seq 10 12`;do rm -rf /srv/ceph/osd3$i/*;done
rm -rf /srv/ceph/ssd/*
rm -rf /etc/ceph/keyring*
rm -rf /tmp/mkfs*

