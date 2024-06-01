echo "启用Mongodb Cluster 验证"

echo "正在创建证书文件...."

function update_conf()
{
	if [ $1 = location ];then
		#本地
		sed -i "s/#-//g" $2
	else
		#远程
		ssh root@$3 sed -i "s/#-//g" $2
	fi
}

cluster_path=/home/mongodb/cluster #cluster path

keyfile_path=/home/mongodb/cluster/keyfile #key存放目录

cluster_ip=('192.168.0.203' '192.168.0.204' '192.168.0.205') #集群ip

run_sh_ip="192.168.0.203" #允许脚本的IP且此IP需要安装MongoDB

shard_num=4 #shard数量

rm -rf keyfile.file

openssl rand -base64 756 > keyfile.file

chmod 600 keyfile.file

echo -e "创建密钥 \033[1;32m 完成 \033[0m"

echo "密钥上传......."

for ip in ${cluster_ip[*]}
do
	echo $ip开始上传
	if [ $ip = $run_sh_ip ];then
		mkdir -p $keyfile_path
		cp keyfile.file $keyfile_path
	else
		ssh root@$ip mkdir -p $keyfile_path
		scp keyfile.file root@$ip:$keyfile_path
	fi
	echo -e "上传完成 \033[1;32m 完成 \033[0m"
done

echo "修改配置文件...."

for ip in ${cluster_ip[*]}
do
	echo $ip
	if [ $ip = $run_sh_ip ];then
		echo "修改config/mongod.conf"
		update_conf "location" $cluster_path/config/mongod.conf
		echo "修改mongos/mongod.conf"
		update_conf "location" $cluster_path/mongos/mongod.conf
		for((i =1;i<=$shard_num;i++))
		do
			echo "修改shard$i/mongod.conf"
			update_conf "location" $cluster_path/shard$i/mongod.conf
		done
	else
		echo "修改config/mongod.conf"
                update_conf "ssh" $cluster_path/config/mongod.conf $ip
                echo "修改mongos/mongod.conf"
                update_conf "ssh" $cluster_path/mongos/mongod.conf $ip
                for((i =1;i<=$shard_num;i++))
                do
                        echo "修改shard$i/mongod.conf"
                        update_conf "ssh" $cluster_path/shard$i/mongod.conf $ip
                done

	fi
done


echo 执行完成
