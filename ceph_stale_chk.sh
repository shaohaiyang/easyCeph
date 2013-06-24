#!/bin/sh
ceph pg dump_stuck stale
ceph pg dump_stuck inactive
ceph pg dump_stuck unclean 
