#!/bin/sh
FILE=/tmp/.health_check
SLEEP_TIME=30
DO="Y"
mobile_num="13666626825"

send_fetion() {
        curl http://mon.53kf.com/f.php?phone="13655896157"\&pwd="reallyred520"\&to="$1"\&msg="$2"
}
reweight_osd() {
	[ $DO = "Y" ] && echo "Take it easy! After $SLEEP_TIME sec, reweigth again...";sleep $SLEEP_TIME;/root/ceph_reweight_osd.sh
}

rm -rf $FILE
ceph health > $FILE

grep -q "HEALTH_OK" $FILE
if [ $? != 0 ];then
	OSD_STATE=`ceph osd stat|awk '{if(($2==$4)&&($4==$6)) {print "OK"}}'`
	if [ "$OSD_STATE" != "OK" ];then
		DO="N"
		OSD_ID=`ceph osd tree|awk '/osd.*down/{print $(NF-2)}'`
		echo "- $OSD_ID down at `date`" >> /tmp/osd_down.log
		STRING="osd $OSD_ID is down."
		echo $STRING
		#send_fetion $mobile_num $STRING
                /etc/init.d/ceph -a start $OSD_ID
	else
		echo "OSD OK."
	fi
	
	PG_STATE=`sed -r -n 's@.* degraded \((.*)\).*@\1@gp' $FILE`
	if [ ! -z "$PG_STATE" ];then
		DO="N"
		STRING="pgmap degraded is $PG_STATE"
		echo $STRING
		#send_fetion $mobile_num $STRING
	else
		echo "PG OK."
	fi

	grep -q "near full" $FILE
	if [ $? = 0 -a $DO = "Y" ];then
		STRING=`cat $FILE`
		echo $STRING
		reweight_osd
	fi

	grep -q "pgs stuck inactive" $FILE
	if [ $? = 0 ];then
		grep -iq "B/s" $FILE
		if [ $? != 0 ];then
		DO="N"
		INACTIVE=`sed -r 's@.*;(.*) pgs stuck inactive;.*@\1@g' $FILE`
echo $INACTIVE
		OSD_ID=`ceph pg dump_stuck inactive|awk '/^[0-9*]/{print $14}'|sed -r -e 's:\[::g' -e 's:\]::g'|awk -F, '{a[$1]++;a[$2]++;a[$3]++} END{for(i in a){if(a[i]=='"$INACTIVE"') print "osd."i}}'` 
		echo "+ $OSD_ID inactive at `date`" >> /tmp/osd_down.log
		STRING="osd $OSD_ID is hang up."
		echo $STRING
		#send_fetion $mobile_num $STRING
                #/etc/init.d/ceph -a restart $OSD_ID
		fi
	else
		echo "PGS active OK."
	fi
else
	echo "ALL Status is OK"
	reweight_osd
fi
