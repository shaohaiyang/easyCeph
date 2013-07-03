#!/bin/sh 
readonly DRIVER_LIST=`pwd`/driver.sn
# A#B#C#D#E A=dc B=room C=rack D=row E=weight(0.000~100)
OSD_POOLS="1#12|ceph1|192.168.0.20|1#1#1#1#20 2#12|ceph2|192.168.0.100|1#1#1#2#20 3#12|ceph3|192.168.0.99|1#1#1#3#20 #4#12|ceph4|192.168.0.91|1#1#1#4#20 #5#3|ceph5|192.168.0.92|1#1#1#5#5"
readonly DEV="eth0"
readonly STEP="12"
readonly PG_NUM="48000"
readonly REP_NUM="3"
readonly AUTH="none" # none or cephx
readonly CRUSH_MAP=/etc/ceph/crush
readonly SSHDO="ssh -p22 -o StrictHostKeyChecking=no -n"
readonly SCPDO="scp -P22 -o StrictHostKeyChecking=no"

[ -s $DRIVER_LIST ] || (echo "Not find $DRIVER_LIST file,check please.";exit 0)

NUM=`grep -c processor /proc/cpuinfo`
NUM=$((NUM/2))
FS_TYPE="xfs"
if [ $FS_TYPE == "xfs" ];then
	FS_OPT="-l internal,lazy-count=1,size=128m -i attr=2 -d agcount=8 -i size=512"
	FS_MOUNT="rw,noexec,nodev,noatime,nodiratime,nobarrier,logbsize=256k,logbufs=8,inode64"
elif [ $FS_TYPE == "ext4" ];then
	FS_OPT="-b 4096 -E stride=16,stripe-width=128 -T largefile"
	FS_MOUNT="rw,sync,noatime,nodiratime,user_xattr,nobarrier,data=writeback"
fi

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
mkdir -p /etc/cron.d/
echo "0 */2 * * * root (ntpdate -o3 $TIME_SRV)" > /etc/cron.d/ceph_ntp
sed -r -i -e '/^$/d' -e '/ntpdate/d' /etc/rc.d/rc.local
echo "ntpdate -o3 $TIME_SRV" >> /etc/rc.d/rc.local
#################################################
ADDR=$(ifconfig $DEV|sed -r -n '/Bcast/s#.* addr:(.*) Bcast.*#\1#gp')
ADDR=${ADDR% }

genCephConfig(){
ntpdate -o3 $TIME_SRV &
sed -r -i '/queue/d' /etc/rc.d/rc.local
cat > /etc/ceph/ceph.conf <<EOF
[global]
        ; For version 0.55 and beyond, you must explicitly enable
        ; or disable authentication with "auth" entries in [global].
	public network = 192.168.0.0/24
	cluster network = 192.168.100.0/24
        auth cluster required = $AUTH
        auth service required = $AUTH
        auth client required = $AUTH
	max open files = 60000
	mon osd full ratio = .95
	mon osd nearfull ratio = .55
	mon debug dump transactions = false
	osd pool default min_size = 1
	osd pool default size = $REP_NUM
	osd pool default pg num = $PG_NUM
	osd pool default pgp num = $PG_NUM
	osd op thread timeout = 60
        osd op threads = $NUM
	osd max backfills = $NUM
        osd disk threads = $NUM
        osd recovery threads = $NUM
	osd recovery max active = $NUM
        keyring = /etc/ceph/keyring
	journal aio = false
	journal dio = false
[osd]
        osd data = /srv/ceph/osd\$id
        osd journal = /srv/ceph/ssd/journal.\$id
        osd journal size = 1024
        osd mkfs type = $FS_TYPE
	debug osd = 5
        keyring = /etc/ceph/keyring.\$name
	filestore fiemap = false
        ; The following assumes ext4 filesystem.
        filestore xattr use omap = true
EOF

for node in $OSD_POOLS;do
        echo "$node"|grep -q "^#"
        [ $? = 0 ] && continue

        xx=$IFS;IFS="|";read -r ids Host ip osds <<<"$node";IFS=$xx
	host=${Host%#}
	id=`echo $ids|cut -d# -f1`
	osd_num=`echo $ids|cut -d# -f2`

        sed -r -i "/$host/d" /etc/hosts
        echo "$ip       $host" >> /etc/hosts
        xx=$IFS;IFS="#";read -r dc room rack row weight<<<"$osds";IFS=$xx

        NODE_ID=$(((id-1)*$STEP))

        j=1
        grep sata $DRIVER_LIST > $DRIVER_LIST.tmp
        while read LINE;do
		[ $j -gt $osd_num ] && break
                dev=`echo $LINE|awk '{print $NF}'`
                label=`echo $LINE|awk '{print $1}'`
                NICK=$((NODE_ID+$j))

                vip=$(echo $ip|awk -F. '{print $1"."$2"."100"."$4}')

                if [ $ADDR = $ip ] ;then
                        hostname $host
                        sed -r -i '/HOSTNAME/d' /etc/sysconfig/network
                        echo "HOSTNAME=$host" >> /etc/sysconfig/network

                        # format them and wait to finished.
			if [ $FS_TYPE == "xfs" ] ;then
                        	mkfs.$FS_TYPE -f $FS_OPT $dev
				xfs_admin -L $label $dev
			elif [ $FS_TYPE == "ext4" ];then
				mkfs.ext4 -L $label $dev
			fi
                        mkdir -p /srv/ceph/osd$NICK
                        sed -r -i "/osd$NICK/d" /etc/rc.d/rc.local
			STRING0=$STRING0"\necho 1024 > /sys/block/${dev#/dev/}/queue/nr_requests;echo 512 > /sys/block/${dev#/dev/}/queue/read_ahead_kb"
                        STRING1=$STRING1"\nmount -t $FS_TYPE -o $FS_MOUNT -L $label /srv/ceph/osd$NICK"
		else
        		$SSHDO $ip "sed -r -i \"/$host/d\" /etc/hosts;echo -e \"$ip\t$host\" >> /etc/hosts"
                fi
                #STRING=$STRING"[osd.$NICK]\n\thost=$host\n\tdevs=$label\n"
                STRING=$STRING"[osd.$NICK]\n\thost=$host\n\tpublic addr = $ip\n\tcluster addr = $vip\n\tdevs=$label\n"
                ((j++))
        done < $DRIVER_LIST.tmp
        rm -rf $DRIVER_LIST.tmp

	echo $Host|grep -q "#"
	[ $? = 0 ] || STRING2=$STRING2"[mon.$id]\n\thost=$host\n\tmon addr=$ip:6789\n"
	if [ $ADDR = $ip ] ;then
       		dev=$(awk '/ssd/{print $NF}' $DRIVER_LIST|head -1)
	        label=$(awk '/ssd/{print $1}' $DRIVER_LIST|head -1)
		# format them and wait to finished.
		if [ $FS_TYPE == "xfs" ] ;then
			mkfs.$FS_TYPE -f $FS_OPT $dev
			xfs_admin -L $label $dev
		elif [ $FS_TYPE == "ext4" ];then
			mkfs.ext4 -L $label $dev
		fi
		mkdir -p /srv/ceph/ssd/mon$id
		sed -r -i "/mon$id/d" /etc/rc.d/rc.local
		STRING1=$STRING1"\nmount -t $FS_TYPE -o $FS_MOUNT -L $label /srv/ceph/ssd/;mkdir -p /srv/ceph/ssd/mon$id"
		STRING0=$STRING0"\necho 1024 > /sys/block/${dev#/dev/}/queue/nr_requests;echo 512 > /sys/block/${dev#/dev/}/queue/read_ahead_kb"
		echo -e $STRING0$STRING1 >> /etc/rc.d/rc.local
	fi
done

echo -en $STRING >> /etc/ceph/ceph.conf
echo -en "\n[mon]\n\tdebug mon = 5\n\tmon max osd = 30000\n\tmon subscribe interval = 300\n\tmon osd down out interval = 300\n\tmon clock drift allowed = 0.5\n\tmon data = /srv/ceph/ssd/mon\$id\n\tkeyring = /etc/ceph/keyring.\$name\n"$STRING2 >> /etc/ceph/ceph.conf
echo "after mount and mkcephfs -a -c /etc/ceph/ceph.conf"
}
#######################################################################
genCrushMap(){
STRING3=$STRING3"# begin crush map\n# devices\n"
STRING4="# buckets\n"
STRING9="root default {\n\tid -1\n\talg straw\n\thash 0"
for node in $OSD_POOLS;do
        echo "$node"|grep -q "^#"
        [ $? = 0 ] && continue

	j=0
	jj=0
	xx=$IFS;IFS="|";read -r ids Host ip osds <<<"$node";IFS=$xx
	host=${Host%#}
	id=`echo $ids|cut -d# -f1`
	osd_num=`echo $ids|cut -d# -f2`
	sed -r -i "/$host/d" /etc/hosts
	echo "$ip	$host" >> /etc/hosts
	xx=$IFS;IFS="#";read -r dc room rack row weight<<<"$osds";IFS=$xx

        NODE_ID=$(((id-1)*$STEP))
        STRING4=$STRING4"host $host {\n\tid -$((id*$STEP))\n\talg straw\n\thash 0\n"
	STRING5="rack rack-$rack {\n\tid -$((rack*$STEP-$rack))\n\talg straw\n\thash 0"
	echo -e $STRING5 > /tmp/.rack$rack.id

	grep sata $DRIVER_LIST > $DRIVER_LIST.tmp
	while read LINE;do
		dev=`echo $LINE|awk '{print $NF}'`
		label=`echo $LINE|awk '{print $1}'`
		((j++))
		[ $j -gt $osd_num ] && break
		NICK=$((NODE_ID+$j))
        	STRING3=$STRING3"device $NICK osd.$NICK\n"
        	STRING4=$STRING4"\titem osd.$NICK weight $weight\n"
	done < $DRIVER_LIST.tmp
	rm -rf $DRIVER_LIST.tmp
	STRING4=$STRING4"}\n"
	i=$(echo "$j * $weight"|bc)
	STRING51="\titem $host weight $i"
	echo -e $STRING51 >> /tmp/.rack$rack.item
	jj=$(echo "$jj+$i"|bc)
	cat /tmp/.rack$rack.id /tmp/.rack$rack.item > /tmp/.rack$rack
	echo "}" >> /tmp/.rack$rack
	if [ -s /tmp/.root$rack.num ] ;then
		old_num=`cat /tmp/.root$rack.num`
	else
		old_num=0
	fi
	new_num=$(echo "$jj+$old_num"|bc)
	echo -e "\titem rack-$rack weight $new_num" > /tmp/.root$rack
	echo $new_num > /tmp/.root$rack.num
done
####################  General crush map rules
rm -rf /tmp/.rack*.* /tmp/.root*.*
echo -e $STRING3"\n# types\ntype 0 osd\ntype 1 host\ntype 2 rack\ntype 3 row\ntype 4 room\ntype 5 datacenter\ntype 6 root\n" > $CRUSH_MAP.tmp
echo -e $STRING4 >> $CRUSH_MAP.tmp
cat /tmp/.rack* >> $CRUSH_MAP.tmp
echo -e $STRING9 >> $CRUSH_MAP.tmp
cat /tmp/.root* >> $CRUSH_MAP.tmp
echo -e "}\n" >> $CRUSH_MAP.tmp
uniq $CRUSH_MAP.tmp > $CRUSH_MAP.txt
rm -rf /tmp/.rack*  /tmp/.root*
cat >> $CRUSH_MAP.txt << EOF
# rules
rule data {
        ruleset 0
        type replicated
        min_size 1
        max_size 10
        step take default
        step chooseleaf firstn 0 type host
        step emit
}
rule metadata {
        ruleset 1
        type replicated
        min_size 1
        max_size 10
        step take default
        step chooseleaf firstn 0 type host
        step emit
}
rule rbd {
        ruleset 2
        type replicated
        min_size 1
        max_size 10
        step take default
        step chooseleaf firstn 0 type host
        step emit
}
# end crush map
EOF
rm -rf $CRUSH_MAP.tmp
crushtool -c $CRUSH_MAP.txt -o $CRUSH_MAP.map
echo "crushtool -c $CRUSH_MAP.txt -o $CRUSH_MAP.map"
}
#######################################################
syncConfig(){
for node in $OSD_POOLS;do
        echo "$node"|grep -q "^#"
        [ $? = 0 ] && continue

        xx=$IFS;IFS="|";read -r ids Host ip osds <<<"$node";IFS=$xx
	host=${Host%#}
	id=`echo $ids|cut -d# -f1`
	osd_num=`echo $ids|cut -d# -f2`
	if [ $ADDR != $ip ] ;then
		echo "==== Copy file -> ( $host ) $ip "
        	$SSHDO $ip "sed -r -i \"/$host/d\" /etc/hosts;echo -e \"$ip\t$host\" >> /etc/hosts"
        	$SCPDO /etc/ceph/ceph.conf $ip:/etc/ceph/
        	$SCPDO /etc/ceph/crush.* $ip:/etc/ceph/
        	$SCPDO /etc/hosts $ip:/etc/
	fi
done
}
exportMap(){
	ceph auth get mon. -o /tmp/authmap
	ceph mon getmap -o /tmp/monmap
	ceph osd getmap -o /tmp/osdmap
}

case "$1" in
	genConfig)
		genCephConfig;;
	genCrushmap)
		genCrushMap;;
	syncConfig)
		syncConfig;;
	exportmap)
		exportMap;;
	*)
		echo $0 "genConfig|genCrushmap|syncConfig|exportmap";;
esac
