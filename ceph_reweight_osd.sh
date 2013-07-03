#!/bin/sh
OSDS="301@302@303@304@305@306@307@308@309@310@311@312#20#0.01"

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
	echo "reweight done."
done
