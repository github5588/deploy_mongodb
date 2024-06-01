# deploy_mongodb
mongodb 集群部署
## 自动配置脚本,基于5.x版本新版本可能会有问题

# MongoDB 分布式集群部署

## 环境
+ centos 7.x 以上版本
+ mongodb 5.x 版本

## 部署操作

* 默认部署配置三个节点，如有多个道理相同，当配置 **Replica Set 副本集** 副本集数量一定为 **奇数** 否则影响仲裁

## 节点IP以及部署规划

| IP地址 | mongos-router[Port] | config-server[Port] | shard[Port]
|:----:| :----: | :----: | :----: | 
| 192.168.0.203 | 27017 | 27018 | shard1:27019,shard2:27020,shard3:27021 | 
| 192.168.0.204 | 27017 | 27018| shard1:27019,shard2:27020,shard3:27021 | 
| 192.168.0.205 | 27017 | 27018 | shard1:27019,shard2:27020,shard3:27021 | 


## 认证配置

在开启认证前，需要将所有的角色 **mongo-config** 、 **mongo-router** 、 **mongo-shard** 都要添加管理员，否则当

配置认证后无法进行管理

+ 在指定目录创建存放密钥的文件夹执行以下命令
+ openssl rand -base64 756 > 密钥文件路径
+ chmod 600 密钥文件路径

    **生成的密钥文件后需要在每个服务器都需要放一份，最好保证路径相同方便配置**

## mongo-config 配置

```
systemLog:
  destination: file
  logAppend: true
  path: /home/mongodb/cluster/config/logs/mongod.log # 这里是log日志路径文件可以不存在路径必须存在

# Where and how to store data.
storage:
  dbPath: /home/mongodb/cluster/config/data # 这里是data日志路径文件可以不存在路径必须存在
  journal:
    enabled: true

# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /home/mongodb/cluster/config/mongod.pid  # 目录必须存在
  timeZoneInfo: /usr/share/zoneinfo

# network interfaces
net:
  port: 27018 # config 端口号
  bindIp: 192.168.0.203 # 服务器IP根据IP不同进行修改

sharding:
  clusterRole: configsvr

replication:
  replSetName: config
security:
  keyFile: "/home/mongodb/cluster/keyfile/keyfile.file" # 密钥路径
  clusterAuthMode: "keyFile"
```

在需要配置mongo-config的服务器执行  **mongod -f** 配置文件路径，当出现 **child process started successfully, parent exiting** 执行成功 

+ mongo **mongo-config ip** --port 27018
+ 执行 
    ```
    rs.initiate(
        {
            _id: "config",
            configsvr: true,
            members: [
                
                { _id : 0, host : "192.168.0.203:27018" }, 
                { _id : 1, host : "192.168.0.204:27018" },
                { _id : 2, host : "192.168.0.205:27018" }
            ]
        }
    )
    ```
+ 查看节点状态

    ```
    rs.status()
    ```
**其中，”_id” : “config”应与配置文件中配置的 replicaction.replSetName 一致，”members” 中的 “host” 为三个节点的 ip 和 port**


## Shard 配置

```
systemLog:
  destination: file
  logAppend: true
  path: /home/mongodb/cluster/shard1/logs/mongod.log # shard1 log 目录必须存在

# Where and how to store data.
storage:
  dbPath: /home/mongodb/cluster/shard1/data # shard1 data 目录必须存在
  journal:
    enabled: true

# how the process runs
processManagement:
  fork: true  # fork and run in background
  pidFilePath: /home/mongodb/cluster/shard1/mongod.pid  # 路径必须存在
  timeZoneInfo: /usr/share/zoneinfo

# network interfaces
net:
  port: 27019 # shard端口
  bindIp: 192.168.0.203 # shard1 ip

sharding:
    clusterRole: shardsvr

replication:
    replSetName: shard1
security:
  keyFile: "/home/mongodb/cluster/keyfile/keyfile.file" # 密钥路径
  clusterAuthMode: "keyFile"

```


+ 在需要配置shard的服务器执行  **mongod -f** 配置文件路径，当出现 **child process started successfully, parent exiting** 执行成功 

+ 随便连接某个shard1的服务器执行 mongo shard1 ip ：27019(shard端口)
+ 执行
    ```
    rs.initiate(
    {
        _id: "shard1",
        members: [
            { _id : 0, host : "10.32.176.80:27019" },
            { _id : 1, host : "10.32.176.81:27019" },
            { _id : 2, host : "10.32.176.82:27019" }
        ]
        }
    )
    ```
+ 查看节点状态

    ```
    rs.status()
    ```
+ shard2、shard3、....shardN 执行的操作相同唯一不同的是需要注意的配置文件的 **replSetName** 属性 **port** , **bindIp**

## 配置 mongos-router

+ 先启动mongos-config 以及 shards 在进行 mongos-router配置

+ 创建配置文件

    ```
    systemLog:
        destination: file
        logAppend: true
        path: /home/mongodb/cluster/mongos/logs/mongod.log # log文件存放位置路径不可为空

    processManagement:
        fork: true  # fork and run in background
        pidFilePath: /home/mongodb/cluster/mongos/mongod.pid  # location of pidfile
        timeZoneInfo: /usr/share/zoneinfo

    net:
        port: 27017 # 端口
        bindIp: 192.168.0.203 # mongo-router 服务器ip

    sharding:
        # mongo-config ip端口
        configDB: config/192.168.0.203:27018,192.168.0.204:27018,192.168.0.205:27018
    security:
        keyFile: /home/mongodb/cluster/keyfile/keyfile.file # 密钥文件

    ```
+ 将此配置分别在作为mongos-router服务器上创建，并执行 **mongos -f** mongos 配置文件路径

+ 启动分片，登录任何一台mongo-router
    ```
    mongo ip:27017

    sh.addShard( "shard1/192.168.0.203:27019,192.168.0.204:27019,192.168.0.205:27019")
    sh.addShard( "shard2/192.168.0.203:27020,192.168.0.204:27020,192.168.0.205:27020")
    sh.addShard( "shard3/192.168.0.203:27021,192.168.0.204:27021,192.168.0.205:27021")
    sh.addShard( "shardN/ip:port,.....")

    ```

    有多少shard 就添加多少 需要注意的是 shard1 这个名字跟shard的配置文件的 **replSetName**有关系
+ 查看状态
    ```
    sh.status()
    ```


## Shard 操作

+ 添加新Shard

   1. 将新shard 以复制集的方式部署到服务器上，具体操作看**shard配置**

   2. 配置完成后登录 mongo router 执行 sh.addShard("shardName/ip:port,ip1:port")

      shardName根据配置的名称而定 ip是复制集的ip用逗号隔开

+  移除Shard

    1. 登录mongo router 执行 **use admin**

    2. 执行 **db.runCommand({listshards:1})** 查看shard情况

    3. 执行 **db.runCommand( {removeshard:“shardName”} )** 进行移除，在执行移除的过程前查看shard状态

       **printShardingStatus()** 如果要移除的数据库的shard标识为 **"primary" : "shardName"** 那么可能需要更长的时间

    4. 如果移除的是主分片需要执行以下操作

        + **use config** 回车执行 **db.runCommand({“moveprimary”:“app”,“to”:“shard2”})** app是要移除的shard 到 shard2

        + 在执行的过程中执行 **db.runCommand( {removeshard:“shardName”} )** 查看返回的 **state** 状态，等变为 **completed** 证明移除完成

        + 再次执行 **db.runCommand({listshards:1})** 看一下还有没有要移除的shard的信息，如果有就等一会
        + 关闭集群 进行重启

    + *shard添加后表中的数据增加到一定的阀值才会往新shard添加数据


## 集群启动顺序
1. 在存放 mongo-config 的服务器 启动所有 mongo-config
2. 在存放所有 mongo-shard 的服务器启动所有shard
3. 在存放所有mongo-router 的服务器启动所有 router 

## 配置SSH 免密登录

1. 执行 **ssh-genkey** 一直回车即可
2. 执行 **cd ~/.ssh** 后输入 **ls** 找到公钥 **id_rsa.pub**
3. 上传公钥到需要免密登录到此台设备的服务器 **ssh-copy-id -i ~/.ssh/id_rsa.pub root@需要远程到此计算机免密登录的IP**   


## 集群启动脚本

```
#!/bin/bash

ip_cluster=('192.168.0.203' '192.168.0.204' '192.168.0.205') #根据集群IP进行修改
cluster_path="/home/mongodb/cluster" #集群路径
mongod_path="/usr/local/mongodb5/bin/mongod" #mongod命令路径
mongos_path="/usr/local/mongodb5/bin/mongos" #mongos命令路径
shard_num=4 #shard数量


## start config
echo "start mongo config"

for ip in ${ip_cluster[*]}
do
	echo "start $ip mongos config"
	if [ $ip = "192.168.0.203" ];then
		config_exist=`ps -ef | grep "$cluster_path/config/mongod.conf" | grep -v grep | wc -l`
		if [ $config_exist = 0 ];then
			$mongod_path -f $cluster_path/config/mongod.conf
			echo "start $ip mongo config success"
		else
			echo "$ip mongos config is start"
		fi
        else
		config_exist=`ssh root@$ip ps -ef | grep "$cluster_path/config/mongod.conf" | grep -v grep | wc -l`
		if [ $config_exist = 0 ];then
			ssh root@$ip $mongod_path -f $cluster_path/config/mongod.conf
			echo "start $ip mongo config success"
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
		if [ $ip = "192.168.0.203" ];then
			shard_exist=`ps -ef | grep "$cluster_path/shard$i/mongod.conf" | grep -v grep | wc -l`
			if [ $shard_exist = 0 ];then
				$mongod_path -f /home/mongodb/cluster/shard$i/mongod.conf
				echo "start $ip mongo shard$i success"
			else
				echo "$ip shard$i is start"
			fi
		else
			shard_exist=`ssh root@$ip ps -ef | grep "$cluster_path/shard$i/mongod.conf" | grep -v grep | wc -l`
			if [ $shard_exist = 0 ];then
				ssh root@$ip $mongod_path -f /home/mongodb/cluster/shard$i/mongod.conf
				echo "start $ip mongo shard$i success"
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
	if [ $ip = "192.168.0.203" ];then
		mongo_exist=`ps -ef | grep "$cluster_path/mongos/mongod.conf" | grep -v grep | wc -l`
		if [ $mongo_exist = 0 ];then
			$mongos_path -f $cluster_path/mongos/mongod.conf
			echo "$ip mongos start success"
		else
			echo "$ip mongos is start"
		fi
	else
		mongo_exist=`ssh root@$ip ps -ef | grep "$cluster_path/mongos/mongod.conf" | grep -v grep | wc -l`
		if [ $mongo_exist = 0 ];then
			ssh root@$ip $mongos_path -f $cluster_path/mongos/mongod.conf
			echo "$ip mongos start success"
		else
			 echo "$ip mongos is start"
		fi
	fi
done


```

+ **192.168.0.203** 是脚本启动的服务器IP 因为ssh 本地没有加免密码登录

+ 使用脚本前需要对集群配置ssh免密登录以及脚本文件配置修改否则报错

## 集群关闭脚本

```
#!/bin/bash

ip_cluster=('192.168.0.203' '192.168.0.204' '192.168.0.205') #集群ip

mongod_path="/usr/local/mongodb5/bin/mongod" # mongod 命令位置
cluster_path="/home/mongodb/cluster" //集群存放位置 config  shard router 必须存放到一个目录下

for ip in ${ip_cluster[*]}
do
	echo "close $ip mongos"
	if [ $ip = "192.168.0.203" ];then
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
		echo "cluster mongos closed"
		break
	fi
	
done

echo "check mongos process success"

echo "close mongo config"


for ip in ${ip_cluster[*]}
do
	echo "close $ip mongo config"
	if [ $ip = "192.168.0.203" ];then
		$mongod_path -f $cluster_path/config/mongod.conf --shutdown
	else
		ssh root@$ip $mongod_path -f $cluster_path/config/mongod.conf --shutdown
	fi
done

shard_num=4 #shard数量

for((i=1;i<=$shard_num;i++));
do
	echo "close shard$i"
	for ip in ${ip_cluster[*]}
	do
		echo "close $ip shard$i start"
		if [ $ip = "192.168.0.203" ];then
			$mongod_path -f $cluster_path/shard$i/mongod.conf --shutdown
		else
			ssh root@$ip $mongod_path -f $cluster_path/shard$i/mongod.conf --shutdown
		fi
	done	
	echo "close shard$i success"
done 

```

+ **192.168.0.203** 是脚本启动的服务器IP 因为ssh 本地没有加免密码登录

+ 使用脚本前需要对集群配置ssh免密登录以及脚本文件配置修改否则报错

## 部署MongoDB 集群脚本

+ 配置文件目录均为自动生成，配置好ip端口即可

```
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

```

##配置认证脚本

```
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

```



