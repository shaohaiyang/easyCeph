#!/bin/sh
FILE=/tmp/.health_check
SLEEP_TIME=30
rm -rf $FILE
ceph -s > $FILE

mobile_num="13666626825"
send_fetion() {
        curl http://mon.53kf.com/f.php?phone="13655896157"\&pwd="reallyred520"\&to="$1"\&msg="$2"
}

grep -iq "health .*ok" $FILE
if [ $? != 0 ];then
	OSD_STATE=$(awk '/osdmap/{if(($3==$5) && ($5==$7)){print "OK"}}' $FILE)
	if [ "$OSD_STATE" != "OK" ];then
		OSD_ID=$(ceph osd tree|awk '/osd.*down/{print $(NF-2)}')
		STRING="osd $OSD_ID is down."
		echo $STRING
		#send_fetion $mobile_num $STRING
	else
		echo "OSD OK."
	fi
	
	grep -iq "pgmap.*degraded" $FILE
	if [ $? = 0 ];then
		PROG=$(sed -r -n '/pgmap/s@.* degraded \((.*)\);.*recovering.*@\1@gp' $FILE)
		STRING="pgmap degraded is $PROG"
		echo $STRING
		#send_fetion $mobile_num $STRING
	else
		echo "PG Normal."
	fi
else
	echo "ALL OK"
        echo "Take easy $SLEEP_TIME sec, Reweigth again..." ;sleep $SLEEP_TIME; /root/ceph_reweight_osd.sh
fi
