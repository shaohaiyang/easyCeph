#!/bin/sh
OSDS="201@202@203@204@205@206@207@208@209@210@211@212#20#0.1"

FILE=/tmp/.osd_tree
rm -rf $FILE
ceph osd tree > $FILE

for osd in $OSDS;do
        echo "$osd"|grep -q "^#"
        [ $? = 0 ] && continue

        xx=$IFS;IFS="#";read -r ids end step<<<"$osd";IFS=$xx
	for id in `echo $ids|tr '@' ' '`;do
		old_weight=$(awk '/osd.'"$id"'/{print $2}' $FILE)
		new_weight=$(echo "$old_weight+$step"|bc)

                BOOL=`echo "$end>=$new_weight"|bc`
                if [ $BOOL -eq 1 ];then
			ceph osd crush reweight osd.$id $new_weight
		fi
	done
done
