#!/bin/bash

#docker环境安装
get_distribution() {
        lsb_dist=""
        if [ -r /etc/os-release ]; then
			lsb_dist="$(. /etc/os-release && echo "$ID")"
        fi
        echo "$lsb_dist"
}
install_docker(){
	lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"
	who=`whoami`
	if [ $who == "root" ];then
		case "$lsb_dist" in
			ubuntu)
				apt-get update -qq >/dev/null
				apt-get install -y -qq curl wget
				docker -v
				if [ $? -ne 0 ]; then
					curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
					if [ $? -ne 0 ]; then
						echo "安装Docker失败"
						exit 1
					fi
				fi
				;;
			centos)
				yum update -y
				yum install curl -y
				docker -v
				if [ $? -ne 0 ]; then
					curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
					if [ $? -ne 0 ]; then
						echo "安装Docker失败"
						exit 1
					fi
				fi
				;;
			*)
				echo "安装Docker失败,仅支持ubuntu/centos系统"
				exit 1
				;;
		esac
		wget http://www.itemtry.com:8081/ipns/epik.itemtry.com/daemon.json -O /etc/docker/daemon.json
        	systemctl enable docker
		systemctl reload docker
		systemctl restart docker
	else
	        case "$lsb_dist" in
                	ubuntu)
                        	sudo apt-get update -qq >/dev/null
                        	sudo apt-get install -y -qq curl wget
                        	sudo docker -v
                        	if [ $? -ne 0 ]; then
                                	sudo curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
                                	if [ $? -ne 0 ]; then
                                        	echo "安装Docker失败"
                                        	exit 1
                                	fi
                        	fi
                        	;;
                	centos)
                        	sudo yum update -y
                        	sudo yum install curl -y
                        	sudo docker -v
                        	if [ $? -ne 0 ]; then
                                	sudo curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
                                	if [ $? -ne 0 ]; then
                                        	echo "安装Docker失败"
                                        	exit 1
                                	fi
                        	fi
                        	;;
                	*)
                        	echo "安装Docker失败,仅支持ubuntu/centos系统"
                        	exit 1
                        	;;
        	esac
		sudo usermod -aG docker $who
        	sudo wget http://www.itemtry.com:8081/ipns/epik.itemtry.com/daemon.json -O /etc/docker/daemon.json
          	sudo systemctl enable docker
        	sudo systemctl reload docker
        	sudo systemctl restart docker
	fi
}

#钱包导入
import_wallet(){
	echo -e "\e[33m输入钱包私钥\e[0m"
	docker exec -it epik-node epik wallet import
}

#初始化daemon与启动daemon
run_daemon(){
ft=true
while $ft
do
	read -p "输入daemon节点数据存储路径 [默认:/data/epik]: " Spath
	read -p "输入API_INFO的IP地址.[本地地址]![RemoteListenAddress]: " Aip
	read -p "输入公网IP或者域名.[非梯子地址,需能正常访问,如果没有,可直接回车跳过]: " Lip
	read -p "输入公网映射端口. [默认1347,可直接回车确认]: " Lport
	Spath=${Spath:=/data/epik}
	Lport=${Lport:=1347}
	if [ $Aip ];then
		ft=false
	fi
done
	cat /proc/cpuinfo|grep adx >> /dev/null
	if [ $? == 0 ];then
		docker pull www.itemtry.com:8443/christismith/epik:adx
		docker run -it --rm --name init-node -v $Spath:/data www.itemtry.com:8443/christismith/epik:adx init-node.sh
		s=`docker ps -a --filter name=init-node|wc -l`
		while  (( $s>=2 ))
		do
				s=`docker ps -a --filter name=init-node|wc -l`
				echo "daemon节点初始化中....."
				sleep 30
		done
		echo "-----------------------------------------"
		docker run -itd --restart always --network host --name epik-node -e EPIK_ALLOW_TRUNCATED_LOG=1 -e NODEHOSTIP=$Aip -e LIBP2P_IP=$Lip -e LIBP2P_PORT=$Lport -v $Spath:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx run-node.sh
		echo "-----------------------------------------"
		sleep 10
	else
		docker pull www.itemtry.com:8443/christismith/epik
		docker run -it --rm --name init-node -v $Spath:/data www.itemtry.com:8443/christismith/epik init-node.sh
		s=`docker ps -a --filter name=init-node|wc -l`
		while  (( $s>=2 ))
		do
            s=`docker ps -a --filter name=init-node|wc -l`
            echo "daemon节点初始化中....."
            sleep 30
		done
		echo "-----------------------------------------"
		docker run -itd --restart always --network host --name epik-node -e EPIK_ALLOW_TRUNCATED_LOG=1 -e NODEHOSTIP=$Aip -e LIBP2P_IP=$Lip -e LIBP2P_PORT=$Lport -v $Spath:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik run-node.sh
		echo "-----------------------------------------"
		sleep 10
	fi
	read -p "创建一个新钱包作为owner地址或者导入现有的钱包私钥,或者跳过 [回车直接跳过! create/import]:" action
	action=${action:=skip}
	case $action in
		"create")
			docker exec -it epik-node epik wallet new bls
			echo "请为该地址发送0.5epk作为gas费用预留"
			;;
		"import")
			import_wallet
			;;
	esac
}

#初始化矿工
#daemon机复用
local_miner_init(){
	read -p "输入miner节点数据存储路径 [默认:/data/miner]: " PATH_PREFIX
	PATH_PREFIX=${PATH_PREFIX:=/data/miner}
	read -p "输入owner钱包地址: " Owner_WALLET
	read -p "是否放入后台运行?[建议初次创建放到前台运行,以便观察运行日志.直接回车以前台方式运行 Y/N;y/n]: " runtype
	runtype=${runtype:="N"}
	API_INFO=`docker exec -it epik-node epik auth api-info --perm admin`
	API_INFO_TEMP=${API_INFO#*=}
	API_INFO=`echo $API_INFO_TEMP|sed 's/\r//g'`
	echo "-----------------------------------------"

	if [ $runtype == "y" ]||[ $runtype == "Y" ];then
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker pull www.itemtry.com:8443/christismith/epik:adx
			docker run -itd --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			echo "-----------------------------------------"
		else
			docker pull www.itemtry.com:8443/christismith/epik
			docker run -itd --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
            echo "----------------------------------------"
		fi
	else
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker pull www.itemtry.com:8443/christismith/epik:adx
			docker run -it --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			echo "-----------------------------------------"
		else
			docker pull www.itemtry.com:8443/christismith/epik
			docker run -it --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			echo "----------------------------------------"
		fi
	fi
}

#单独miner机
remote_miner_init(){
	read -p "输入miner节点数据存储路径 [默认:/data/miner]: " PATH_PREFIX
	PATH_PREFIX=${PATH_PREFIX:=/data/miner}
	# read -p "Enter Owner Wallet Address: " Owner_WALLET
	read -p "是否放入后台运行?[建议初次创建放到前台运行,以便观察运行日志.直接回车以前台方式运行 Y/N;y/n]:  " runtype
	runtype=${runtype:="N"}

	if [ $runtype == "y" ]||[ $runtype == "Y" ];then
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker pull www.itemtry.com:8443/christismith/epik:adx
			docker run -itd --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			echo "-----------------------------------------"
		else
			docker pull www.itemtry.com:8443/christismith/epik
			docker run -itd --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
            echo "----------------------------------------"
		fi
	else
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker pull www.itemtry.com:8443/christismith/epik:adx
			docker run -it --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			echo "-----------------------------------------"
		else
			docker pull www.itemtry.com:8443/christismith/epik
			docker run -it --rm -e FULLNODE_API_INFO=$API_INFO -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			echo "----------------------------------------"
		fi
	fi
}

#启动矿工
#daemon机复用
local_run_miner(){
	read -p "输入容器运行后缀编号 [建议以数字顺序编号]: " name
	read -p "输入miner节点数据存储路径 [默认:/data/miner]: " PATH_PREFIX
	read -p "输入公网IP或者域名.[非梯子地址,需能正常访问,如果没有,可直接回车]: " LIBP2PIP
	read -p "输入公网映射端口. [如果没有,可直接回车]: " LIBP2PPORT
	name=${name:=1}
	PATH_PREFIX=${PATH_PREFIX:=/data/miner}
	API_INFO=`docker exec -it epik-node epik auth api-info --perm admin`
	API_INFO_TEMP=${API_INFO#*=}
	FULLNODE_API_INFO=`echo $API_INFO_TEMP|sed 's/\r//g'`
	if [ ! $LIBP2PPORT ];then
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx run-miner.sh
		else
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT  -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik run-miner.sh
		fi
	else
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp -p $LIBP2PPORT:2458  www.itemtry.com:8443/christismith/epik:adx run-miner.sh
		else
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp -p $LIBP2PPORT:2458 www.itemtry.com:8443/christismith/epik run-miner.sh
		fi
	fi
}

#单独miner机
remote_run_miner(){
	read -p "输入容器运行后缀编号 [建议以数字顺序编号]: " name
	read -p "输入miner节点数据存储路径 [默认:/data/miner]: " PATH_PREFIX
	read -p "输入公网IP或者域名.[非梯子地址,需能正常访问,如果没有,可直接回车]: " LIBP2PIP
	read -p "输入公网映射端口. [如果没有,可直接回车]: " LIBP2PPORT
	name=${name:=1}
	PATH_PREFIX=${PATH_PREFIX:=/data/miner}
	FULLNODE_API_INFO=$API_INFO
	if [ ! $LIBP2PPORT ];then
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx run-miner.sh
		else
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT  -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik run-miner.sh
		fi
	else
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp -p $LIBP2PPORT:2458  www.itemtry.com:8443/christismith/epik:adx run-miner.sh
		else
			docker run -itd --restart always --name epik-miner-$name -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT -v $PATH_PREFIX:/data -v /var/tmp/epik_tmp:/data/tmp -p $LIBP2PPORT:2458 www.itemtry.com:8443/christismith/epik run-miner.sh
		fi
	fi
}

#daemon机上脚本质押
daemon_miner_pledge(){
tf=true
while $tf
do
	read -p "输入矿工的MinerId: " minerid
	echo -e "\e[35m查询 worker ID\e[0m"
	docker exec -it epik-node epik state miner-info $minerid
	read -p "输入 Worker ID: " workerid
	read -p "输入质押的钱包地址: " Pledge_WALLET
	read -p "输入owner钱包地址: " Owner_WALLET

	echo "-----------------------------------------"
	echo "矿工Id:" $minerid
	echo "质押的钱包地址: "$Pledge_WALLET
	echo "owner钱包地址: " $Owner_WALLET
	echo "Worker ID: " $workerid
	echo "-----------------------------------------"
	echo -e "\e[35m信息确认?[Y/N 默认 Y/y]\e[0m\c ";read -p "" Sure
	Sure=${Sure:="Y"}
	
	if [ $Sure == "y" ]||[ $Sure == "Y" ];then
		echo -e "\e[36m矿工 "$minerid" 质押 1000epk \e[0m"
		docker exec -it epik-node epik client mining-pledge add --from=$Pledge_WALLET $minerid 1000epk
		sleep 5
		echo -e "\e[36m向 "$workerid" 发放 0.1epk 作为gas手续费 \e[0m"
		docker exec -it epik-node epik send --from=$Pledge_WALLET $workerid 0.1epk
		sleep 5
		echo -e "\e[36m向 "$Owner_WALLET" 提供 0.0000000000001epk 作为初始质押,后续请手机APP进行质押增加! \e[0m"
		docker exec -it epik-node epik client retrieve-pledge --from=$Pledge_WALLET --target=$Owner_WALLET 0.0000000000001epk
		sleep 60
		echo -e "\e[36m授权 "$minerid" 使用 "$Owner_WALLET" 的流量 \e[0m"
		docker exec -it epik-node epik client retrieve-bind --from=$Owner_WALLET $minerid
		tf=false
	fi
done
}
#daemon机上，只做worker的gas发放与流量绑定，矿工质押与流量质押由手机钱包完成
daemon_miner_bind(){
tf=true
while $tf
do
	read -p "输入矿工的minerID: " minerid
	echo -e "\e[35m查询 worker ID\e[0m"
	docker exec -it epik-node epik state miner-info $minerid
	read -p "输入Worker ID: " workerid
	read -p "输入owner钱包地址: " Owner_WALLET

	echo "-----------------------------------------"
	echo "矿工Id:" $minerid
	echo "owner钱包地址: " $Owner_WALLET
	echo "Worker ID: " $workerid
	echo "-----------------------------------------"
	echo -e "\e[35m信息确认?[Y/N 默认 Y/y]\e[0m\c ";read -p "" Sure
	Sure=${Sure:="Y"}
	
	if [ $Sure == "y" ]||[ $Sure == "Y" ];then
		echo -e "\e[36m向 "$workerid" 发放 0.1epk 作为gas手续费 \e[0m"
		docker exec -it epik-node epik send --from=$Owner_WALLET $workerid 0.1epk
		sleep 5
        echo -e "\e[36m向 "$Owner_WALLET" 提供 0.0000000000001epk　作为初始质押,后续请手机APP进行质押增加! \e[0m"
		docker exec -it epik-node epik client retrieve-pledge --from=$Owner_WALLET --target=$Owner_WALLET 0.0000000000001epk
		sleep 60
		echo -e "\e[36m授权 "$minerid" 使用 "$Owner_WALLET" 的流量 \e[0m"
		docker exec -it epik-node epik client retrieve-bind --from=$Owner_WALLET $minerid
		tf=false
	fi
done
}
#miner机上脚本质押
miner_pledge(){
tf=true
while $tf
do
	read -p "输入容器运行后缀名字: " name
	name=${name:=1}
	read -p "输入矿工的MinerId: " minerid
	echo -e "\e[35m查询 worker ID\e[0m"
	docker exec -it epik-miner-$name epik state miner-info $minerid
	read -p "输入 Worker ID: " workerid
	read -p "输入质押的钱包地址: " Pledge_WALLET
	read -p "输入owner钱包地址: " Owner_WALLET

	echo "-----------------------------------------"
	echo "矿工 Id:" $minerid
	echo "质押的钱包地址: "$Pledge_WALLET
	echo "owner钱包地址: " $Owner_WALLET
	echo "Worker ID: " $workerid
	echo "-----------------------------------------"
	echo -e "\e[35m信息确认?[Y/N default Y/y]\e[0m\c ";read -p "" Sure
	Sure=${Sure:="Y"}
	
	if [ $Sure == "y" ]||[ $Sure == "Y" ];then
		echo -e "\e[36m矿工 "$minerid" 质押 1000epk \e[0m"
		docker exec -it epik-miner-$name epik client mining-pledge add --from=$Pledge_WALLET $minerid 1000epk
		sleep 5
		echo -e "\e[36m向 "$workerid" 发放 0.1epk 作为gas手续费 \e[0m"
		docker exec -it epik-miner-$name epik send --from=$Pledge_WALLET $workerid 0.1epk
		sleep 5
		echo -e "\e[36m向 "$Owner_WALLET" 提供 0.0000000000001epk 作为初始质押,后续请手机APP进行质押增加! \e[0m"
		docker exec -it epik-miner-$name epik client retrieve-pledge --from=$Pledge_WALLET --target=$Owner_WALLET 0.0000000000001epk
		sleep 60
		echo -e "\e[36m授权 "$minerid" 使用 "$Owner_WALLET" 的流量 \e[0m"
		docker exec -it epik-miner-$name epik client retrieve-bind --from=$Owner_WALLET $minerid
		tf=false
	fi
done
}
#miner机上，只做worker的gas发放与流量绑定，矿工质押与流量质押由手机钱包完成
miner_bind(){
	tf=true
while $tf
do
	read -p "输入容器运行后缀名字: " name
	read -p "输入矿工的minerID: " minerid
	echo -e "\e[35m查询 worker ID\e[0m"
	docker exec -it epik-miner-$name epik state miner-info $minerid
	read -p "输入 Worker ID: " workerid
	read -p "输入owner钱包地址: " Owner_WALLET

	echo "-----------------------------------------"
	echo "矿工Id: " $minerid
	echo "owner钱包地址: " $Owner_WALLET
	echo "Worker ID: " $workerid
	echo "-----------------------------------------"
	echo -e "\e[35m信息确认?[Y/N 默认 Y/y]\e[0m\c ";read -p "" Sure
	Sure=${Sure:="Y"}
	
	if [ $Sure == "y" ]||[ $Sure == "Y" ];then
		echo -e "\e[36m向 "$workerid" 发放 0.1epk 作为gas手续费 \e[0m"
		docker exec -it epik-node epik send --from=$Owner_WALLET $workerid 0.1epk
		sleep 5
        echo -e "\e[36m向 "$Owner_WALLET" 提供 0.0000000000001epk　作为初始质押,后续请手机APP进行质押增加! \e[0m"
		docker exec -it epik-miner-$name epik client retrieve-pledge --from=$Pledge_WALLET --target=$Owner_WALLET 0.0000000000001epk
		sleep 60
		echo -e "\e[36m授权 "$minerid" 使用 "$Owner_WALLET" 的流量 \e[0m"
		docker exec -it epik-node epik client retrieve-bind --from=$Owner_WALLET $minerid
		tf=false
	fi
done
}

#自动批量初始化、启动、质押
#通过脚本质押，则需要输入质押钱包
#不用脚本质押，刚只做创建、启动、流量绑定与gas费发放
auto_miners(){
	#预设相关参数
ft=true
while $ft
do
    FULLNODE_API_INFO=$API_INFO
    echo "FULLNODE_API_INFO: " $FULLNODE_API_INFO
    echo -e "\e[35m确认上面的API_INFO信息?[Y/N default Y/y]\e[0m\c ";read -p "" Sure
	Sure=${Sure:="Y"}
    if [ $Sure != "Y" ] && [ $Sure != "y" ];then
		read -p "输入FULLNODE_API_INFO: " FULLNODE_API_INFO
	fi
	#read -p "Enter FULLNODE_API_INFO: " FULLNODE_API_INFO
	read -p "输入批量miner节点数据存储路径主路径: " PATH_PREFIX
	read -p "是否通过脚本直接质押？[y/Y N/n default N/n] " pledge_s
	pledge_s=${pledge_s:="N"}
	if [ $pledge_s == "Y" ] || [ $pledge_s == "y" ];then
		read -p "输入质押的pledge钱包地址: " Pledge_WALLET
	fi
	echo "Owner Wallet Address: " $Owner_WALLET
	echo -e "\e[35m确认上面的owner地址?[Y/N default Y/y]\e[0m\c ";read -p "" Sure
	Sure=${Sure:="Y"}
    if [ $Sure != "Y" ] && [ $Sure != "y" ];then
		read -p "输入owner钱包地址: " Owner_WALLET
	fi
	read -p "计划运行多少个miner: " NUM
	read -p "从多少编号开始: " BEG
	read -p "输入公网IP或者域名.[非梯子地址,需能正常访问,如果没有,可直接回车]: " LIBP2PIP
	read -p "输入公网映射端口. [如果没有,可直接回车]: " LIBP2PPORT
	
	echo "-----------------------------------------"
	echo "miner节点数据存储路径:" $PATH_PREFIX
	echo "质押的pledge钱包地址: "$Pledge_WALLET
	echo "owner钱包地址: " $Owner_WALLET
	echo "计划运行miner数量: " $NUM
	echo "从此编号开始: " $BEG
	echo "公网IP或者域名: " $LIBP2PIP
	echo "公网映射端口: " $LIBP2PPORT	
	echo "FULLNODE_API_INFO: " $FULLNODE_API_INFO
	echo "-----------------------------------------"
	echo -e "\e[35m信息确认?[Y/N default Y/y]\e[0m\c ";read -p "" Sure
	Sure=${Sure:="Y"}
	
	if [ $Sure == "Y" ] || [ $Sure == "y" ];then
		ft=false
	fi
done

	#初始始化矿工
	END=$(expr $BEG + $NUM)
	for ((i=$BEG;i<$END;i++))
	do
	if [ -f $PATH_PREFIX/miner$BEG/miner/minerid ];then
			cat /proc/cpuinfo|grep adx >> /dev/null
			if [ $? == 0 ];then
				docker pull www.itemtry.com:8443/christismith/epik:adx
				docker run -itd --rm -e FULLNODE_API_INFO=$FULLNODE_API_INFO -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			else
				docker pull www.itemtry.com:8443/christismith/epik
				docker run -itd --rm -e FULLNODE_API_INFO=$FULLNODE_API_INFO -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
			fi
		else
			ft=true
			while $ft;do
				if [ -f $PATH_PREFIX/miner$BEG/miner/minerid ];then
					ft=false
				else
                    node_count=`docker ps --filter="name=miner-init" | wc -l`
                    echo "矿工创建中 .........................................."
                    until [ ${node_count} == 1 ]; 
                    do
                        node_count=`docker ps --filter="name=miner-init" | wc -l`
                        echo "如果等待时间超过15分钟，请切换一个新终端，查看一下运行的容器 <docker ps -a> ，是否有miner-init容器；如果有,请查看日志 <docker logs -f miner-init>"
                        sleep 60
                    done
					# cat /proc/cpuinfo|grep adx >> /dev/null
					# if [ $? == 0 ];then
					# 	docker pull www.itemtry.com:8443/christismith/epik:adx
					# 	docker run -itd --rm --name miner-init -e FULLNODE_API_INFO=$FULLNODE_API_INFO -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
					# else
					# 	docker pull www.itemtry.com:8443/christismith/epik
					# 	docker run -itd --rm --name miner-init -e FULLNODE_API_INFO=$FULLNODE_API_INFO -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik-miner init --nosync --owner $Owner_WALLET --create-worker-key
					# fi
					# sleep 60
				fi
			done
		fi
	done
	
	#启动矿工并质押
	for ((i=$BEG;i<$END;i++))
	do
		ft=true
		while $ft
		do
		if [ -f $PATH_PREFIX/miner$i/miner/minerid ];then
			if [ ! $LIBP2PPORT ];then
				cat /proc/cpuinfo|grep adx >> /dev/null
				if [ $? == 0 ];then
					docker run -itd --restart always --name epik-miner-$i -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx run-miner.sh
				else
					docker run -itd --restart always --name epik-miner-$i -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$LIBP2PPORT  -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik run-miner.sh
				fi
			else
				port=$(expr $LIBP2PPORT - 1 + $i)
				cat /proc/cpuinfo|grep adx >> /dev/null
				if [ $? == 0 ];then
					docker run -itd --restart always --name epik-miner-$i -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$port -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp -p $port:2458  www.itemtry.com:8443/christismith/epik:adx run-miner.sh
				else
					docker run -itd --restart always --name epik-miner-$i -e EPIK_ALLOW_TRUNCATED_LOG=1 -e FULLNODE_API_INFO=$FULLNODE_API_INFO -e LIBP2P_IP=$LIBP2PIP -e LIBP2P_PORT=$port -v $PATH_PREFIX/miner$i:/data -v /var/tmp/epik_tmp:/data/tmp -p $port:2458 www.itemtry.com:8443/christismith/epik run-miner.sh
				fi
			fi
			sleep 15
			
			#质押
			if [ $pledge_s == "Y" ] || [ $pledge_s == "y" ];then
				minerid=`cat $PATH_PREFIX/miner$i/miner/minerid`
				S=`docker inspect --format '{{.State.Running}}' epik-miner-$i`
				if $S;then
                    echo "操作容器 epik-miner-$i  minerId: " $minerid
					workerid=`docker exec -it epik-miner-$i epik state miner-info ${minerid}|grep Worker|awk '{print $NF}'|tr -d '\r'`
					sleep 30
					echo -e "\e[36m矿工 "$minerid" 质押 1000epk \e[0m"
					docker exec -it epik-miner-$i epik client mining-pledge add --from=$Pledge_WALLET $minerid 1000epk
					sleep 5
					echo -e "\e[36m向 "$workerid" 发放 0.1epk 作为gas手续费 \e[0m"
					docker exec -it epik-miner-$i epik send --from=$Pledge_WALLET $workerid 0.1epk
					sleep 5
					echo -e "\e[36m向 "$Owner_WALLET" 提供 0.0000000000001epk　作为初始质押,后续请手机APP进行质押增加! \e[0m"
					docker exec -it epik-miner-$i epik client retrieve-pledge --from=$Pledge_WALLET --target=$Owner_WALLET 0.0000000000001epk
					sleep 60
					echo -e "\e[36m授权 "$minerid" 使用 "$Owner_WALLET" 的流量 \e[0m"
					docker exec -it epik-miner-$i epik client retrieve-bind --from=$Owner_WALLET $minerid
					ft=false
				fi
			else
				minerid=`cat $PATH_PREFIX/miner$i/miner/minerid`
				S=`docker inspect --format '{{.State.Running}}' epik-miner-$i`
				if $S;then
                    echo "操作容器 epik-miner-$i  minerId: " $minerid
					workerid=`docker exec -it epik-miner-$i epik state miner-info ${minerid}|grep Worker|awk '{print $NF}'|tr -d '\r'`
					sleep 30
					echo -e "\e[36m向 "$workerid" 发放 0.1epk 作为gas手续费 \e[0m"
					docker exec -it epik-miner-$i epik send --from=$Pledge_WALLET $workerid 0.1epk
					sleep 5
                    echo -e "\e[36m向 "$Owner_WALLET" 提供 0.0000000000001epk　作为初始质押,后续请手机APP进行质押增加! \e[0m"
					docker exec -it epik-miner-$i epik client retrieve-pledge --from=$Owner_WALLET --target=$Owner_WALLET 0.0000000000001epk
					sleep 60
					echo -e "\e[36m授权 "$minerid" 使用 "$Owner_WALLET" 的流量 \e[0m"
					docker exec -it epik-miner-$i epik client retrieve-bind --from=$Owner_WALLET $minerid
					ft=false
				fi
			fi
		fi
		done
	done
}
#daemon节点同步状态查看
check_node(){
	docker exec -it epik-node epik sync status
	docker exec -it epik-node epik sync wait
}
#miner info查看
check_miner(){
	read -p "输入容器运行后缀编号: " name
	docker exec -it epik-miner-$name epik-miner info
}
#API_INFO查看
show_confg(){
	echo "-----------------------------------------"
	API_INFO=`docker exec -it epik-node epik auth api-info --perm admin`
	echo "FULLNODE_API_INFO: ${API_INFO#*=}"
	echo "-----------------------------------------"
}
#钱包管理
show_wallet(){
	echo "-----------------------------------------"
	docker exec -it epik-node epik wallet list
	echo "-----------------------------------------"
}
export_wallet(){
	read -p "输入钱包地址: " add
	echo "-----------------------------------------"
	docker exec -it epik-node epik wallet export $add
	echo "-----------------------------------------"
}
delete_wallet(){
	read -p "输入钱包地址: " add
        echo "-----------------------------------------"
        docker exec -it epik-node epik wallet delete $add
        echo "-----------------------------------------"
}

set_coinbase(){
    read -p "输入归集钱包地址: " add
    read -p "本机所有miner容器节点归集；连续多个miner容器节点归集；单个miner容器节点归集: [all/cont/single 默认：全部] "  cointype
    cointype=${cointype:=all}
    case $cointype in
    "all")
        containers=(`docker ps -qa  --filter "name=epik-miner" --format "table {{.Names}}"|grep -v NAMES`)
        for i in ${containers[@]}; do
            echo "-----------------$i---------------------"
            docker exec -it $i epik-miner actor set-coinbase --really-do-it $add
        done
        ;;
    "cont")
	    read -p "开始容器后缀编号: " BEG
        read -p "截止容器后缀编号: " END
        for ((i=$BEG;i<=$END;i++))
        do
            echo "------------epik-miner-$i---------------"
            docker exec -it epik-miner-$i epik-miner actor set-coinbase --really-do-it $add
        done
        ;;
    "single")
        read -p "输入容器后缀编号: " name
        docker exec -it epik-miner-$name epik-miner actor set-coinbase --really-do-it $add
        ;;
	esac
}

show_all_miners(){
	containers=(`docker ps -qa  --filter "name=epik-miner*" --format "table {{.Names}}"|grep -v NAMES`)
	# printf "%-14s||%-9s||%-5s||%-10s\n" "container" "Minerid" "Power" "Total Minerd"
	for i in ${containers[@]}; do
		S=`docker inspect --format '{{.State.Running}}' $i`
		if $S;then
			M=`docker exec -it $i epik-miner info |sed -n '2p'|awk '{print $2}'|tr -d '\r'`
			P=`docker exec -it $i epik-miner info |grep Power|awk '{print $2}'|tr -d '\r'`
			T=`docker exec -it $i epik-miner info |grep "Total Mined"|awk '{print $3}'|tr -d '\r'`
			Print=`printf "%-14s||%-9s||%s"M"||%s"epk"\n" $i $M $P $T`
			echo $Print
		fi
	done
}

export_snapshot(){
	T=`date +%Y%m%d`
	docker exec -it epik-node epik chain export --recent-stateroots 1000 --skip-old-msgs /data/latest_$T.car
}

import_snapshot(){
	echo "-----------------------------------------"
	read -p "输入daemon节点数据存储路径 [默认:/data/epik]: " Spath
	Spath=${Spath:=/data/epik}
	read -p "输入快照url地址或者本地路径.[http://ip:port/filename.car]: " url
	container=(`docker ps -qa  --filter "name=epik-node*" --format "table {{.Names}}"|grep -v NAMES|wc -l`)
	if [ $container == 1 ];then
		S=`docker inspect --format '{{.State.Running}}' epik-node`
		if $S;then
			docker rm -f epik-node
		fi
		echo "删除daemon的datastore数据和kvlog数据"
		sudo rm -rf $Spath/node/datastore 
		sudo rm -rf $Spath/node/kvlog
		if [ -d $Spath/node/datastore ] || [ -d $Spath/node/kvlog ];then
			echo "删除失败，请手动删除数据"
		else
			cat /proc/cpuinfo|grep adx >> /dev/null
			if [ $? == 0 ];then
			docker pull www.itemtry.com:8443/christismith/epik:adx
			docker run -it --rm --network host -v $Spath:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik daemon --import-snapshot $url
			else
			docker pull www.itemtry.com:8443/christismith/epik
			docker run -it --rm --network host -v $Spath:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik daemon --import-snapshot $url
			fi
		fi
	else
		cat /proc/cpuinfo|grep adx >> /dev/null
		if [ $? == 0 ];then
		docker pull www.itemtry.com:8443/christismith/epik:adx
		docker run -it --rm --network host -v $Spath:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik:adx epik daemon --import-snapshot $url
		else
		docker pull www.itemtry.com:8443/christismith/epik
		docker run -it --rm --network host -v $Spath:/data -v /var/tmp/epik_tmp:/data/tmp www.itemtry.com:8443/christismith/epik epik daemon --import-snapshot $url
		fi
	fi
}

#容器管理
stop_container(){
    read -p "输入容器名,可同时多个容器,以空格隔开: " name
	echo "-----------------------------------------"
    docker stop $name
    echo "-----------------------------------------"
}
restart_container(){
    read -p "输入容器名,可同时多个容器,以空格隔开: " name
	echo "-----------------------------------------"
    docker restart $name
    echo "-----------------------------------------"
}
update_container(){
	read -p "输入容器名,可同时多个容器,以空格隔开: " name
	echo "-----------------------------------------"
	docker run --rm -v  /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --cleanup --run-once $name
	echo "-----------------------------------------"
}

daemon(){
while true 
	do
cat << EOF
-----------------------------------------------------
    _____           __  __ _       _        ____
   |_   _|__  _ __ |  \/  (_)_ __ (_)_ __  / ___|
     | |/ _ \| '_ \| |\/| | | '_ \| | '_ \| |  _
     | | (_) | |_) | |  | | | | | | | | | | |_| |
     |_|\___/| .__/|_|  |_|_|_| |_|_|_| |_|\____|
             |_|
  --------------------------------------------------  
  此脚本为EpiK社区大使9527编写，已获得其本人授权使用
          联系方式:https://topmining.io/
  --------------------------------------------------  
(1) 启动daemon节点容器
(2) 钱包私钥导入
(3) 脚本方式质押矿工与流量(非安全)
(4) 仅为矿工流量绑定授权(安全)
(5) 查看daemon同步状态
(6) 查看daemon节点的FULLNODE_API_INFO
(7) 查看daemon节点所有钱包地址
(8) 导出钱包私钥
(9) 删除钱包
(10) 容器更新
(11) 导出daemon快照
(12) 导入daemon快照
(13) 重启容器
(0) Exit
EOF
		read -p "请输入要执行的选项: " input
		case $input in
			1)
				run_daemon
				;;
			2)
				import_wallet
				;;
			3)
				daemon_miner_pledge
				;;
			4)
				daemon_miner_bind
				;;
			5)
				check_node
				;;
			6)
				show_confg
				;;
			7)
				show_wallet
				;;
			8)
				export_wallet
				;;
			9)
				delete_wallet
				;;
			10)
				update_container
				;;
			11)
				export_snapshot
				;;
			12)
				import_snapshot
				;;
            13)
                restart_container
                ;;
			*)
				break
				;;
		esac
#	fi
done
}

miner(){
read -p "输入daemon节点的FULLNODE_API_INFO信息: " API_INFO
read -p "输入owner钱包地址: " Owner_WALLET
while true 
	do
	if [ ! $API_INFO ] || [ ! $Owner_WALLET ];then
		echo -e "\e[31m需要输入api信息与owner钱包地址 \e[0m"
		read -p "输入daemon节点的FULLNODE_API_INFO信息O: " API_INFO
        read -p "输入owner钱包地址:  " Owner_WALLET
		continue
	else
cat << EOF
-----------------------------------------------------
    _____           __  __ _       _        ____
   |_   _|__  _ __ |  \/  (_)_ __ (_)_ __  / ___|
     | |/ _ \| '_ \| |\/| | | '_ \| | '_ \| |  _
     | | (_) | |_) | |  | | | | | | | | | | |_| |
     |_|\___/| .__/|_|  |_|_|_| |_|_|_| |_|\____|
             |_|
  --------------------------------------------------  
  此脚本为EpiK社区大使9527编写，已获得其本人授权使用
          联系方式:https://topmining.io/
  --------------------------------------------------  
(1) 矿工miner初始化创建
(2) 启动miner节点容器
(3) 脚本方式质押矿工与流量(非安全)
(4) 仅为矿工流量绑定授权(安全)
(5) 设置收益归集
(6) 批量创建miner并自动完成启动与质押
(7) 查看矿工miner信息
(8) 查看当前设备上所有矿工miner信息
(9) 容器更新
(10) 重启容器
(0) Exit
EOF
			read -p "请输入要执行的选项: " input
			case $input in
				1)
					remote_miner_init
					;;
				2)
					remote_run_miner
					;;
				3)
					miner_pledge
					;;
				4)
					miner_bind
					;;
				5)
					set_coinbase
					;;
				6)
					auto_miners
					;;
				7)
					check_miner
					;;
				8)
					show_all_miners
					;;
				9)
					update_container
					;;
                10)
                    restart_container
                    ;;
				*)
					break
					;;
			esac
	fi
done
}

all(){
while true 
	do
cat << EOF
-----------------------------------------------------
    _____           __  __ _       _        ____
   |_   _|__  _ __ |  \/  (_)_ __ (_)_ __  / ___|
     | |/ _ \| '_ \| |\/| | | '_ \| | '_ \| |  _
     | | (_) | |_) | |  | | | | | | | | | | |_| |
     |_|\___/| .__/|_|  |_|_|_| |_|_|_| |_|\____|
             |_|
  --------------------------------------------------  
  此脚本为EpiK社区大使9527编写，已获得其本人授权使用
          联系方式:https://topmining.io/
  --------------------------------------------------  
(1) 启动daemon节点容器
(2) 钱包私钥导入
(3) 矿工miner初始化创建
(4) 启动miner节点容器
(5) 脚本方式质押矿工与流量(非安全)
(6) 仅为矿工流量绑定授权(安全)
(7) 设置收益归集
(8) 批量创建miner并自动完成启动与质押
(9) 查看daemon同步状态
(10) 查看矿工miner信息
(11) 查看当前设备上所有矿工miner信息
(12) 查看daemon节点的FULLNODE_API_INFO
(13) 查看daemon节点所有钱包地址
(14) 导出钱包私钥
(15) 删除钱包
(16) 容器更新
(17) 导出daemon快照
(18) 导入daemon快照 
(19) 重启容器
(0) 退回上一层
EOF
		read -p "请输入要执行的选项: " input
		case $input in
			1)
				run_daemon
				;;
			2)
				import_wallet
				;;
			3)
				local_miner_init
				;;
			4)
				local_run_miner
				;;
			5)
				daemon_miner_pledge
				;;
			6)
				daemon_miner_bind
				;;
			7)
				set_coinbase
				;;
			8)
				auto_miners
				;;
			9)
				check_node
				;;
			10)
				check_miner
				;;
			11)
				show_all_miners
				;;
			12)
                show_confg
				;;
			13)
				show_wallet
				;;
			14)
				export_wallet
				;;
			15)
				delete_wallet
				;;
			16)
				update_container
				;;			
			17)
				export_snapshot
				;;
			18)
				import_snapshot
				;;
            19)
                restart_container
                ;;
			*)
				break
				;;
		esac

done
}
while true
do
cat << EOF
-----------------------------------------------------
    _____           __  __ _       _        ____
   |_   _|__  _ __ |  \/  (_)_ __ (_)_ __  / ___|
     | |/ _ \| '_ \| |\/| | | '_ \| | '_ \| |  _
     | | (_) | |_) | |  | | | | | | | | | | |_| |
     |_|\___/| .__/|_|  |_|_|_| |_|_|_| |_|\____|
             |_|
  --------------------------------------------------  
  此脚本为EpiK社区大使9527编写，已获得其本人授权使用
          联系方式:https://topmining.io/
  --------------------------------------------------  
(1) 安装docker环境
(2) daemon节点运行配置
(3) miner节点运行配置
(4) 单机复用daemon与miner节点混合运行
(0) exit
EOF
	read -p "请输入要执行的选项: " input
	case $input in
		1)
			install_docker
			;;
		2)
			daemon
			;;
		3)
			miner
			;;
		4)
			all
			;;
		0)
			exit
			;;
	esac
done