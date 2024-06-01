echo "####################################################################"
echo "##                                                                ##"
echo "##                    安装 MongoDB  集群  环境                    ##"
echo "##                                                                ##"
echo "##                                                                ##"
echo "####################################################################"


#ip_cluster=()
ip_cluster=('192.168.0.203' '192.168.0.204' '192.168.0.205') # 集群IP
run_sh_ip="192.168.0.203" #允许脚本的IP且此IP需要安装MongoDB
cluster_dir=/home/mongodb/cluster
shard_num=4 #shard数量
config_port=27018 #config 端口
mongos_port=27017 #mongos 端口
shards_port=('27019' '27020' '27021' '27022')


#动态生成conf
function  create_conf()
{
        rm -rf temp.conf
        if [ $1 = 1 ];then
                #config
                cp config/mongod.conf temp.conf
                sed -i "s/27018/$config_port/g" temp.conf
                sed -i "s/192.168.0.203/$2/g" temp.conf
        elif [ $1 = 2 ];then
                #mongos
                cp mongos/mongod.conf temp.conf
                sed -i "s/27017/$mongos_port/g" temp.conf
                sed -i "s/192.168.0.203/$2/g" temp.conf
                configdb="config\/"
                for ips in ${ip_cluster[*]}
                do
                        configdb+=$ips:$config_port","
                done
                length=${#configdb}-1
                configdb=${configdb:0:length}
 #               echo $configdb
                sed -i "s/cfdb/$configdb/g" temp.conf
        elif [ $1 = 3 ];then
                #shard
                cp shard/mongod.conf temp.conf
                sed -i "s/27019/$2/g" temp.conf
                sed -i "s/192.168.0.203/$3/g" temp.conf
                sed -i "s/sharddir/shard$4/g" temp.conf
        else
                echo "参数错误"
        fi
}


echo "输入yes进行环境配置"

read -p "" input

if [ $input = yes ];then

echo "正在执行............"


if [ ${#ip_cluster[*]} = 0 ];then
	echo "请配置 ip_cluster"
else
	echo "正在准备 MoongoDB 环境"
	for ip in ${ip_cluster[*]}
	do
		echo $ip 解压mongodb
		if [ $ip = $run_sh_ip ];then
			#判断压缩包是否存在
			if [ -e mongodb.tgz ];then
				#解压文件
				tar -zxvf mongodb.tgz
				rm -rf /usr/local/mongodb5
				mv mongodb-linux-x86_64-enterprise-rhel70-5.0.5 /usr/local/mongodb5
				
				echo -e "安装mongodb \033[1;32m 成功 \033[0m"
				mkdir -p $cluster_dir/config/data
				mkdir -p $cluster_dir/config/logs
				mkdir -p $cluster_dir/mongos/data
				mkdir -p $cluster_dir/mongos/logs
				for((i= 1;i<=$shard_num; i++))
				do
					mkdir -p $cluster_dir/shard$i/data
					mkdir -p $cluster_dir/shard$i/logs
				done
				echo -e "目录结构创建\033[1;32m 完成 \033[0m"
				echo 拷贝配置文件
				create_conf 1 $ip
				cp temp.conf $cluster_dir/config/mongod.conf
				echo -e "$ip拷贝config配置 \033[1;32m 成功 \033[0m"
				create_conf 2 $ip
				cp temp.conf $cluster_dir/mongos/mongod.conf
				echo -e "$ip拷贝mongos配置 \033[1;32m 成功 \033[0m"
				for((i= 1;i<=$shard_num; i++))
				do
					j=`expr $i - 1`
					echo ${shards_port[j]}
					create_conf 3 ${shards_port[j]} $ip $i 
					cp temp.conf $cluster_dir/shard$i/mongod.conf
					echo -e "$ip拷贝shard$i 配置 \033[1;32m 成功 \033[0m"
					
				done		
			else
				echo mongodb.tgz未找到
			fi
		else
			#上传压缩包到服务器
			scp mongodb.tgz root@$ip:/home/mongodb.tgz
			#进行解压
			ssh root@$ip tar -zxvf /home/mongodb.tgz -C /home
			ssh root@$ip rm -rf /usr/local/mongodb5
			ssh root@$ip mv /home/mongodb-linux-x86_64-enterprise-rhel70-5.0.5 /usr/local/mongodb5
			echo -e "安装mongodb \033[1;32m 成功 \033[0m"
			ssh root@$ip mkdir -p $cluster_dir/config/data
			ssh root@$ip mkdir -p $cluster_dir/config/logs
			ssh root@$ip mkdir -p $cluster_dir/mongos/data
			ssh root@$ip mkdir -p $cluster_dir/mongos/logs
			for((i= 1;i<=$shard_num; i++))
                        do
                             ssh root@$ip mkdir -p $cluster_dir/shard$i/data
                             ssh root@$ip mkdir -p $cluster_dir/shard$i/logs
                        done
                        echo -e "目录结构创建\033[1;32m 完成 \033[0m"
                        echo 拷贝配置文件
			create_conf 1 $ip
			scp temp.conf root@$ip:$cluster_dir/config/mongod.conf
			echo -e "$ip拷贝config配置 \033[1;32m 成功 \033[0m"
		
			create_conf 2 $ip
			scp temp.conf root@$ip:$cluster_dir/mongos/mongod.conf
			echo -e "$ip拷贝mongos配置 \033[1;32m 成功 \033[0m"
			
			for((i= 1;i<=$shard_num; i++))
			do
				j=`expr $i - 1`
				create_conf 3 ${shards_port[j]} $ip $i
				scp temp.conf root@$ip:$cluster_dir/shard$i/mongod.conf
				echo -e "$ip拷贝shard$i 配置 \033[1;32m 成功 \033[0m"
				
			done
			#echo -e "拷贝配置文件\033[1;32m 完成 \033[0m"

		fi
	done
fi
echo mongoDB 安装在所有服务器的 /usr/local/mongodb5 下
echo -e "集群目录:\033[44;37;5m $cluster_dir \033[0m "
fi

