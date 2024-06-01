#!/bin/bash

ip_cluster=('192.168.0.203' '192.168.0.204' '192.168.0.205')
shell_ip="192.168.0.203" #shell执行ip
mongod_path="/usr/local/mongodb5/bin/mongod"
cluster_path="/home/mongodb/cluster"

for ip in ${ip_cluster[*]}
do
	echo "close $ip mongos"
	if [ $ip = $shell_ip ];then
		killall mongos
        else
		ssh root@$ip killall mongos
        fi
done

#echo ${ip_cluster[1]}

kill_mongos_status=1

echo "check mongos process"

while (( kill_mongos_status = 1 ))
do
	#检测进程是否完全杀死
	server_1=`ps -ef | grep "mongos" | grep -v grep | wc -l`
	server_2=`ssh root@${ip_cluster[1]} ps -ef | grep "mongos" | grep -v grep | wc -l`
	server_3=`ssh root@${ip_cluster[2]} ps -ef | grep "mongos" | grep -v grep | wc -l`
	
	if [[ $server_1 = 0 ]] && [[ $server_2 = 0 ]] && [[ $server_3 = 0 ]];then
		echo -e  "cluster mongos \033[1;32m closed \033[0m"
		break
	fi
	
done

echo -e "check mongos process \033[1;32m success \033[0m"

echo "close mongo config"


for ip in ${ip_cluster[*]}
do
	echo "close $ip mongo config"
	if [ $ip = $shell_ip ];then
		$mongod_path -f $cluster_path/config/mongod.conf --shutdown
	else
		ssh root@$ip $mongod_path -f $cluster_path/config/mongod.conf --shutdown
	fi
	echo -e "close $ip mongo config \033[1;32m success \033[0m"
done

shard_num=4

for((i=1;i<=$shard_num;i++));
do
	echo "close shard$i"
	for ip in ${ip_cluster[*]}
	do
		echo "close $ip shard$i start"
		if [ $ip = $shell_ip ];then
			$mongod_path -f $cluster_path/shard$i/mongod.conf --shutdown
		else
			ssh root@$ip $mongod_path -f $cluster_path/shard$i/mongod.conf --shutdown
		fi
	done	
	echo -e "close shard$i \033[1;32m success \033[0m"
done 

echo @@@@@@@@@@@@@@@@@@@@@@@Process Status@@@@@@@@@@@@@@@@@@@@@@@
for ip in ${ip_cluster[*]}
do
	echo $ip mongodb process
	if [ $ip = $shell_ip ];then
		ps -ef | grep mongod
	else
		ssh root@$ip ps -ef | grep mongod
	fi
done
echo @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
