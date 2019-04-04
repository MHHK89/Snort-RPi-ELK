#!/bin/bash
 SNORT_NEEDED=$1
 declare -i SLEEPTIME=1
 SLEEPFORMAT="m"
 DATE=`date +%d-%m-%Y:%H:%M:%S`
 declare -i STARTING_IP_ADDR=30
 DOCKER_NAME="si" # short for snort instance
 LOCAL_ETHNAME="stap" # name for ovs-port
 MIRROR_NAME="snortmirror" # mirror name of ovs
 DOCKER_IMAGE="snort"


 # Need to specify the number of snort instances you want to create. e.g  ./init.sh 16 - else error is given
 if [[ -z "$SNORT_NEEDED" ]]
 then
 echo "Please enter the a valid integer, to create snort instances"
 exit 1
 fi

 if [ $SNORT_NEEDED ]
 then
 if [ ! $(echo "$SNORT_NEEDED" | grep -E "^[0-9]+$") ]
 then
 echo "Please enter the a valid integer, to create snort instances"
 exit 1

 else
 for ((i=1;i<=$SNORT_NEEDED;i++)); do
 # create docker instance
 /usr/bin/docker run -itd --name $DOCKER_NAME$i -v /home/ubuntu/docker-snort/script/ruleprofiling/: /etc/snort/ruleprofiling/ $DOCKER_IMAGE

 # pipework docker instance / connect docker instance to OpenVswitch
 /bin/bash /home/ubuntu/docker-snort/pipework/pipework dockerbr -i eth1 -l $LOCAL_ETHNAME$i $DOCKER_NAME$i 192.168.0.$STARTING_IP_ADDR/24

 # create ovs mirror if needed
 ##/usr/bin/ovs-vsctl -- --id=@m create mirror name=$MIRROR_NAME$i --add bridge dockerbr mirrors @m

 # add snort port to mirroring
 /usr/bin/ovs-vsctl -- --id=@eth1 get port eth1 -- set mirror $MIRROR_NAME$i select_src_port=@eth1 select_dst_port=@eth1
 /usr/bin/ovs-vsctl -- --id=@$LOCAL_ETHNAME$i get port $LOCAL_ETHNAME$i -- set mirror $MIRROR_NAME$i output-port=@$LOCAL_ETHNAME$i

 # configure mysql connection and sensorname for barnyard2

 BY2_MYSQL_CONNECTION='output database: log, mysql, user=snort password=password dbname=snort host=192.168.10.20 sensor_name=sensor0'

 /usr/bin/docker exec -i $DOCKER_NAME$i /bin/sh -c "echo'$BY2_MYSQL_CONNECTION$i' >> /etc/snort/barnyard2.conf"
 # Start Snort
 /usr/bin/docker exec -i $DOCKER_NAME$i /usr/local/bin/snort -c /etc/snort/snort.conf -i eth1 &

 # Start barnyard2
 /usr/bin/docker exec -i $DOCKER_NAME$i /usr/local/bin/barnyard2 -c /etc/snort/barnyard2.conf -d /var/log/snort -f snort.u2 -w /var/log/snort/barnyard2.waldo &

 # Wait 1 minute
 sleep $SLEEPTIME$SLEEPFORMAT
 
 done
 fi
 fi