#!/bin/bash

disk_format() {
	cd /tmp
	sudo apt-get install -y wget
	for ((j=1;j<=3;j++))
	do
		wget https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh 
		if [[ -f /tmp/vm-disk-utils-0.1.sh ]]; then
			bash /tmp/vm-disk-utils-0.1.sh -b /var/lib/mongo -s
			if [[ $? -eq 0 ]]; then
				sed -i 's/disk1//' /etc/fstab
				umount /var/lib/mongo/disk1
				mount /dev/md0 /var/lib/mongo
			fi
			break
		else
			echo "download vm-disk-utils-0.1.sh failed. try again."
			continue
		fi
	done
		
}

install_mongo3() {
    # Configure mongodb.list file with the correct location
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
    echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-3.2.list

    # Disable THP
    #sudo echo never > /sys/kernel/mm/transparent_hugepage/enabled
    #sudo echo never > /sys/kernel/mm/transparent_hugepage/defrag
    #sudo grep -q -F 'transparent_hugepage=never' /etc/default/grub || echo 'transparent_hugepage=never' >> /etc/default/grub

    # Install updates
    sudo apt-get -y update

    # Modified tcp keepalive according to https://docs.mongodb.org/ecosystem/platforms/windows-azure/
    sudo bash -c "sudo echo net.ipv4.tcp_keepalive_time = 120 >> /etc/sysctl.conf"

    #Install Mongo DB
    sudo apt-get install -y mongodb-org

    # Uncomment this to bind to all ip addresses
    sudo sed -i -e 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/g' /etc/mongod.conf
    sudo service mongod restart
}

install_mongo3
disk_format

#start replica set
mongod --dbpath /var/lib/mongo/ --config /etc/mongod.conf --replSet powerzeerplset --logpath /var/log/mongodb/mongod.log --fork

#check if mongod started or not
sleep 15
n=`ps -ef |grep "mongod --dbpath /var/lib/mongo/" |grep -v grep|wc -l`
if [[ $n -eq 1 ]];then
    echo "replica set started successfully"
else
    echo "replica set started failed!"
fi

#set mongod auto start
cat > /etc/init.d/mongod1 <<EOF
#!/bin/bash
#chkconfig: 35 84 15
#description: mongod auto start
. /etc/init.d/functions
Name=mongod1
start() {
if [[ ! -d /var/run/mongodb ]];then
mkdir /var/run/mongodb
chown -R mongod:mongod /var/run/mongodb
fi
mongod --dbpath /var/lib/mongo/ --replSet powerzeerplset --logpath /var/log/mongodb/mongod.log --fork --config /etc/mongod.conf
}
stop() {
pkill mongod
}
restart() {
stop
sleep 15
start
}
case "\$1" in 
    start)
	start;;
	stop)
	stop;;
	restart)
	restart;;
	status)
	status \$Name;;
	*)
	echo "Usage: service mongod1 start|stop|restart|status"
esac
EOF
chmod +x /etc/init.d/mongod1
chkconfig mongod1 on
