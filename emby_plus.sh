#!/bin/bash

if [ $1 ]; then
	docker stop emby 2>/dev/null
        docker rm emby 2>/dev/null
	cpu_arch=$(uname -m)
	case $cpu_arch in
                "x86_64" | *"amd64"*)
                        docker pull emby/embyserver:4.8.0.56
			;;
                "aarch64" | *"arm64"* | *"armv8"* | *"arm/v8"*)
                        docker pull emby/embyserver_arm64v8:4.8.0.56
                        ;;
                *)
                        echo "目前只支持intel64和amd64架构，你的架构是：$cpu_arch"
                        exit 1
                        ;;
        esac
	
	docker_exist=$(docker images |grep emby/embyserver |grep 4.8.0.56)
	if [ -z "$docker_exist" ]; then
		echo "拉取镜像失败，请检查网络，或者翻墙后再试"
		exit 1
	fi

        if [ $2 ]; then
		if [ -s $2/docker_address.txt ]; then
			docker_addr=$(head -n1 $2/docker_address.txt)
		else
			echo "请先配置 $2/docker_address.txt 后重试"
			exit 1	
		fi
	else
		if [ -s /etc/xiaoya/docker_address.txt ]; then
			docker_addr=$(head -n1 /etc/xiaoya/docker_address.txt)
		else
                        echo "请先配置 /etc/xiaoya/docker_address.txt 后重试"
                        exit 1
                fi
	fi

	echo "测试xiaoya的联通性.......尝试连接 $docker_addr"
	wget -4 -q -T 5 -O /tmp/test.md "$docker_addr/d/README.md"
	test_size=$(du -k /tmp/test.md |cut -f1)
	if [[ "$test_size" -eq 196 ]] || [[ "$test_size" -eq 65 ]] ||[[ "$test_size" -eq 0 ]]; then
		echo "请检查xiaoya是否正常运行后再试"
		exit 1
	else
		echo "xiaoya容器正常工作"	
	fi

	echo "清理媒体库原来保存的元数据和配置......."
        mkdir -p $1/temp
	rm -rf $1/config 
	echo "清理完成"
        free_size=$(df -P $1 |tail -n1|awk '{print $4}')
	free_size=$((free_size))
        if [ "$free_size" -le 146800640 ]; then
		free_size_G=$((free_size/1024/1024))
                echo "空间剩余容量不够： $free_size_G""G 小于最低要求140G"
                exit 1
        fi

	mkdir -p $1/xiaoya
	mkdir -p $1/config
	chmod 755 $1
	chown root:root $1
	local_sha=$(docker inspect --format='{{index .RepoDigests 0}}' xiaoyaliu/glue:latest  |cut -f2 -d:)
	remote_sha=$(curl -s "https://hub.docker.com/v2/repositories/xiaoyaliu/glue/tags/latest"|grep -o '"digest":"[^"]*' | grep -o '[^"]*$' |tail -n1 |cut -f2 -d:)
	if [ ! "$local_sha" == "$remote_sha" ]; then
		docker rmi xiaoyaliu/glue:latest
	fi


	if command -v ifconfig >/dev/null 2>&1; then
		docker0=$(ifconfig docker0 | grep "inet " |awk '{print $2}'|tr -d "addr:" |head -n1)
	else
		docker0=$(ip addr show docker0 |grep "inet " |awk '{print $2}'|tr -d "addr:" |head -n1|cut -f1 -d/)
	fi

	if [ $2 ]; then
        	docker run -i --security-opt seccomp=unconfined --rm --net=host -v $1:/media -v $2:/etc/xiaoya -e LANG=C.UTF-8  xiaoyaliu/glue:latest /update_all.sh
                	#echo "http://$docker0:8096" > $2/emby_server.txt
			echo "http://$docker0:6908" > $2/emby_server.txt
			echo e825ed6f7f8f44ffa0563cddaddce14d > $2/infuse_api_key.txt
			chmod -R 777 $1/*
	else
		if [ -s /etc/xiaoya/docker_address.txt ]; then
			docker run -i --security-opt seccomp=unconfined --rm --net=host -v $1:/media -v /etc/xiaoya:/etc/xiaoya -e LANG=C.UTF-8  xiaoyaliu/glue:latest /update_all.sh
			config_dir="/etc/xiaoya"
		else	
			docker_name=$(docker ps |grep xiaoya|awk '{print $NF}')
			config_dir=$(docker inspect $docker_name |grep Source |head -n1 |cut -f2 -d:|tr -d '\", ')
        		docker run -i --security-opt seccomp=unconfined --rm --net=host -v $1:/media -v $config_dir:/etc/xiaoya -e LANG=C.UTF-8  xiaoyaliu/glue:latest /update_all.sh
		fi	
                	#echo "http://$docker0:8096" > $config_dir/emby_server.txt
			echo "http://$docker0:6908" > $config_dir/emby_server.txt
			echo e825ed6f7f8f44ffa0563cddaddce14d > $config_dir/infuse_api_key.txt
			chmod -R 777 $1/*
	fi
	
	if ! grep xiaoya.host /etc/hosts; then
		echo -e "127.0.0.1\txiaoya.host\n" >> /etc/hosts
		xiaoya_host="127.0.0.1"
	else
		xiaoya_host=$(grep xiaoya.host /etc/hosts |awk '{print $1}' |head -n1)	
	fi
	echo "开始安装Emby容器....."
	#wget -q -O /tmp/Emby.Server.Implementations.dll http://docker.xiaoya.pro/Emby.Server.Implementations.dll
	case $cpu_arch in
		"x86_64" | *"amd64"*)
			docker run -d --name emby -v $1/config:/config -v $1/xiaoya:/media -v /etc/nsswitch.conf:/etc/nsswitch.conf --network=host --add-host="xiaoya.host:$xiaoya_host" --user 0:0 --restart always emby/embyserver:4.8.0.56
			#docker cp /tmp/Emby.Server.Implementations.dll emby:/system/
			#docker exec -i emby chmod 644 /system/Emby.Server.Implementations.dll
			#docker restart emby
			echo "一键全家桶全部安装完成"
			;;
		"aarch64" | *"arm64"* | *"armv8"* | *"arm/v8"*)
		        docker run -d --name emby -v $1/config:/config -v $1/xiaoya:/media -v /etc/nsswitch.conf:/etc/nsswitch.conf --network=host --add-host="xiaoya.host:$xiaoya_host" --user 0:0 --restart always emby/embyserver_arm64v8:4.8.0.56
			#docker cp /tmp/Emby.Server.Implementations.dll emby:/system/
                        #docker exec -i emby chmod 644 /system/Emby.Server.Implementations.dll
                        #docker restart emby
			echo "一键全家桶全部安装完成"
                        ;;
		*)
			echo "目前只支持intel64和amd64架构，你的架构是：$cpu_arch"
			exit 1
			;;
	esac		
	sleep 5
	if ! curl -I -s http://$docker0:2345/ | grep -q "302"; then 
		dockername=$(docker ps |grep xiaoyaliu/alist |grep 5678|head -n1|awk '{print $NF}')
		echo "重启 xiaoya"
		docker restart $dockername 2>/dev/null
	fi       	
	echo "开始安装 Resilio 同步软件"
	bash -c "$(curl http://docker.xiaoya.pro/resilio.sh)" -s $1 $2
else
	echo "请在命令后输入 -s /媒体库目录 再重试"
	exit 1
fi

