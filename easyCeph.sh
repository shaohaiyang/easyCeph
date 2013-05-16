#!/bin/sh 
OSD_POOLS="OS-FS1|192.168.0.82|/dev/vdb@/dev/vdc@/dev/vdd OS-FS2|192.168.0.84|/dev/vdb@/dev/vdc@/dev/vdd #OS-FS3|192.168.0.85|/dev/vdb@/dev/vdc@/dev/vdd"
FS_TYPE="xfs"
FS_OPT="-l internal,lazy-count=1,size=128m -i attr=2 -d agcount=8 -i size=512"
### Time Zone 
ZONE="Asia/Shanghai"
### Time server
TIME_SRV="211.115.194.21 133.100.11.8 142.3.100.15"

### set timezone and language
grep -w -q $ZONE /etc/sysconfig/clock
if [ $? = 1 ];then
        sed -r -i "s:ZONE=.*:ZONE=\"$ZONE\":" /etc/sysconfig/clock
        cp -a /usr/share/zoneinfo/$ZONE /etc/localtime
fi

TIME_SRV="0.pool.ntp.org $TIME_SRV"
ntpdate -o3 $TIME_SRV
mkdir -p /etc/cron.d/
echo "0 */2 * * * root (ntpdate -o3 $TIME_SRV)" > /etc/cron.d/ceph_ntp
sed -r -i -e '/^$/d' -e '/ntpdate/d' /etc/rc.d/rc.local
echo "ntpdate -o3 $TIME_SRV" >> /etc/rc.d/rc.local

#################################################
ADDR=$(ifconfig $DEV|sed -r -n '/Bcast/s#.* addr:(.*) Bcast.*#\1#gp')
ADDR=${ADDR% }

cat > /etc/ceph/ceph.conf <<EOF
[global]
        ; For version 0.55 and beyond, you must explicitly enable
        ; or disable authentication with "auth" entries in [global].
        auth cluster required = cephx
        auth service required = cephx
        auth client required = cephx
        keyring = /etc/ceph/keyring
[osd]
        osd data = /srv/ceph/osd\$id
        osd journal = /srv/ceph/osd\$id/journal
        osd journal size = 512
        keyring = /etc/ceph/keyring.\$name
        osd mkfs type = $FS_TYPE
        ; solve rbd data corruption (sileht: disable by default in 0.48)
        filestore fiemap = false
        ; The following assumes ext4 filesystem.
        filestore xattr use omap = true
EOF

i=1
for node in $OSD_POOLS;do
        echo "$node"|grep -q "^#"
        [ $? = 0 ] && continue

	xx=$IFS;IFS="|";read -r host ip osds <<<"$node";IFS=$xx
	sed -r -i "/$host/d" /etc/hosts
	echo "$ip	$host" >> /etc/hosts
	IP_NUM=$(echo $ip|awk -F. '{printf("%03d%03d",$3,$4)}')
	mkdir -p /srv/ceph/mon$IP_NUM
	STRING2=$STRING2"[mon.$IP_NUM]\n\thost=$host\n\tmon addr=$ip:6789\n"
	j=1
	for dev in `echo "$osds"|tr '@' ' '`;do
		jj=$(echo $j|awk '{printf("%02d",$j)}')
		NICK=$IP_NUM$jj
		if [ $ADDR = $ip ] ;then
			hostname $host
			sed -r -i '/HOSTNAME/d' /etc/sysconfig/network
			echo "HOSTNAME=$host" >> /etc/sysconfig/network

			mkfs.$FS_TYPE -f $FS_OPT $dev
			mkdir -p /srv/ceph/osd$NICK
			sed -r -i "/osd$NICK/d" /etc/rc.d/rc.local
			echo "mount -t $FS_TYPE -o rw,noexec,nodev,noatime,nodiratime,barrier=0 $dev /srv/ceph/osd$NICK" >> /etc/rc.d/rc.local
		fi
		STRING=$STRING"[osd.$NICK]\n\thost=$host\n\tdevs=$dev\n"
		((j++))
	done
done
echo -en $STRING >> /etc/ceph/ceph.conf
echo -en "\n[mon]\n\tmon data = /srv/ceph/mon\$id\n\tkeyring = /etc/ceph/keyring.\$name\n"$STRING2 >> /etc/ceph/ceph.conf

echo "after mount and mkcephfs -a -c /etc/ceph/ceph.conf"
