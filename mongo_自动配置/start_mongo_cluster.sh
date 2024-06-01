#!/bin/bash

ip_cluster=('192.168.0.203' '192.168.0.204' '192.168.0.205')
cluster_path="/home/mongodb/cluster"
mongod_path="/usr/local/mongodb5/bin/mongod"
mongos_path="/usr/local/mongodb5/bin/mongos"
shard_num=4
shell_ip="192.168.0.203"

## start config
echo "start mongo config"

for ip in ${ip_cluster[*]}
do
	echo "start $ip mongos config"
	if [ $ip = $shell_ip ];then
		config_exist=`ps -ef | grep "$cluster_path/config/mongod.conf" | grep -v grep | wc -l`
		if [ $config_exist = 0 ];then
			$mongod_path -f $cluster_path/config/mongod.conf
			echo -e "start $ip mongo config \033[1;32m success \033[0m"
		else
			echo "$ip mongos config is start"
		fi
        else
		config_exist=`ssh root@$ip ps -ef | grep "$cluster_path/config/mongod.conf" | grep -v grep | wc -l`
		if [ $config_exist = 0 ];then
			ssh root@$ip $mongod_path -f $cluster_path/config/mongod.conf
			echo -e "start $ip mongo config \033[1;32m success \033[0m"
		else
			  echo "$ip mongos config is start"
		fi
        fi
done


# start shard

for((i=1;i<=$shard_num;i++));
do
	echo "start shard$i"
	for ip in ${ip_cluster[*]}
	do
		if [ $ip = $shell_ip ];then
			shard_exist=`ps -ef | grep "$cluster_path/shard$i/mongod.conf" | grep -v grep | wc -l`
			if [ $shard_exist = 0 ];then
				$mongod_path -f /home/mongodb/cluster/shard$i/mongod.conf
				echo -e "start $ip mongo shard$i \033[1;32m success \033[0m"
			else
				echo "$ip shard$i is start"
			fi
		else
			shard_exist=`ssh root@$ip ps -ef | grep "$cluster_path/shard$i/mongod.conf" | grep -v grep | wc -l`
			if [ $shard_exist = 0 ];then
				ssh root@$ip $mongod_path -f /home/mongodb/cluster/shard$i/mongod.conf
				echo -e "start $ip mongo shard$i \033[1;32m success \033[0m"
			else
				echo "$ip shard$i is start"
			fi
		fi
	done
done 

#start mongos

echo "start mongos"

for ip in ${ip_cluster[*]}
do
	echo "start $ip mongos"
	if [ $ip = $shell_ip ];then
		mongo_exist=`ps -ef | grep "$cluster_path/mongos/mongod.conf" | grep -v grep | wc -l`
		if [ $mongo_exist = 0 ];then
			$mongos_path -f $cluster_path/mongos/mongod.conf
			echo -e "$ip mongos start \033[1;32m success \033[0m"
		else
			echo "$ip mongos is start"
		fi
	else
		mongo_exist=`ssh root@$ip ps -ef | grep "$cluster_path/mongos/mongod.conf" | grep -v grep | wc -l`
		if [ $mongo_exist = 0 ];then
			ssh root@$ip $mongos_path -f $cluster_path/mongos/mongod.conf
			echo -e "$ip mongos start \033[1;32m success \033[0m"
		else
			 echo "$ip mongos is start"
		fi
	fi
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


#echo "Close 203 Mongos"

#killall mongos

#echo "Close 204 mongos"

#ssh root@192.168.0.204 killall mongos

#echo "Close 205 mongos"

#ssh root@192.168.0.205 killall mongos


#p_mongos_count=`ps -ef | grep "mongos" | grep -v grep | wc -l`

#echo $p_mongos_count




