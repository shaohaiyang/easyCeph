#!/bin/sh
rm -rf /usr/bin/ceph* /usr/bin/monmaptool /usr/bin/osdmaptool /usr/bin/rados /usr/bin/librados-config /usr/bin/fetch_file /usr/bin/crushtool
rm -rf /usr/sbin/ceph-* /usr/sbin/rcceph
rm -rf /usr/lib64/libboost_* /usr/lib64/libcephfs.so.1* /usr/lib64/libedit.so.0* /usr/lib64/libleveldb.so* /usr/lib64/librados.so.2* /usr/lib64/librbd.so.1* /usr/lib64/libsmime3.so /usr/lib64/libsnappy.so.1* /usr/lib64/libsoftokn3.so /usr/lib64/libsqlite3.so.0* /usr/lib64/libssl3.so /usr/lib64/rados-classes/
rm -rf /sbin/mkcephfs /sbin/mount.ceph
rm -rf /etc/ceph/
cd /usr/local/bin
rm -rf crushtool librados-config monmaptool osdmaptool rados rbd rest-bench ceph*
cd /usr/local/lib
rm -rf ceph libcephfs.* librados.so* librbd.so* rados-classes
rm -rf /usr/local/sbin/mkcephfs
cd /root
