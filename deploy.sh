#!/bin/bash

################################################################################################
# Deploy zabbix proxy with psql db (Postgres)                                                  #
# developed by tmiklu v1.0					                               #
# 				                                                               #
################################################################################################

clear

echo -e "\n
	 \tWelcome in Zabbix proxy deployment tools \n
         \tThis tools will deploy zabbix proxy to Zabbix master server (Brampton)\n
	 \tTake action, press letter:\n
	 \ta. Deploy fresh Zabbix proxy with psql db\n
         \tb. Remove existing proxy and psql (Dangerous)\n
         \tc. Exit\n
	"

read -p "Enter your option: " USERINPUT


YUM=/usr/bin/yum

case $USERINPUT in
  #
  ##
  ### CASE "A"
  ##
  #
  a)
    echo "Checking Selinux status..."
    SELINUXSTATUS=$(getenforce)

    if [ $SELINUXSTATUS == "Enforcing" ]
     then
      echo -e "SElinux is enabled and during the installation needs to be disabled and put into the permissive mode."
      sed -ie 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
      setenforce 0
    else
      echo -e "SElinux is in permissive mode. No action required"
    fi

	echo -e "-------> let's update repos"
	$YUM update -y > /dev/null

	# add repo for zabbix LTS 4.0
	REPOZABBIX=$(yum repolist enabled | grep -Po 'zabbix\/x86\_64' | wc -l)

	if [ $REPOZABBIX == 1 ] 
     then
      echo "Repo zabbix exists..."
    else
 	  echo "Adding repo zabbix LTS 4.0"
      rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
    fi
        
    # add repo for psql
    REPOPSQL=$(yum repolist | grep -iPo 'pgdg96')
   	if [ $REPOPSQL == 1 ]
     then
       echo "Repo pgsql exists..."
    else
      echo "Adding repo psql..."
      $YUM install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
    fi
    
    # install proxy-pgsql
    ZABBIXPROXY=$(rpm -qa | grep -P 'zabbix\-proxy\-pgsql\-4\.0\.18\-1\.el7\.x86\_64' | wc -l)

    if [ $ZABBIXPROXY == 1 ]
     then
	  echo -e "Installed =$(rpm -qa | grep -P 'zabbix\-proxy\-pgsql\-4\.0\.18\-1\.el7\.x86\_64')"
    else
   	  echo -e "Installing zabbix-proxy-pgsql..."
      $YUM install zabbix-proxy-pgsql-4.0.18-1.el7.x86_64 -y
    fi

    # install postgres server 
    POSTGRESSERVER=$(rpm -qa | grep -P 'postgresql\-server\-9\.2\.24\-2\.el7\_7\.x86\_64' | wc -l)
      
    if [ $POSTGRESSERVER == 1 ]
     then
      echo -e "Installed $(rpm -qa | grep -P 'postgresql\-server\-9\.2\.24\-2\.el7\_7\.x86\_64')" 
    else
      echo -e "Installing..."
      $YUM install postgresql-server -y
    fi

    # init postgres db store
    postgresql-setup initdb
    
    # working directory
    cd / 	
    
    # backup config
    echo "backup config to /var/lib/pgsql/data/postgresql.conf.bak"
    cp -pa /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.bak
    cp -pa /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.bak

	echo "changing config with sed."
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
    # pgsql listen on default 5432
    sed -i 's/#port = 5432/port = 5432/g' /var/lib/pgsql/data/postgresql.conf

    sed -i 's/local/#local/g' /var/lib/pgsql/data/pg_hba.conf
    sed -i 's/host/#host/g' /var/lib/pgsql/data/pg_hba.conf
    echo "local all all trust" >> /var/lib/pgsql/data/pg_hba.conf
    echo "host all all 127.0.0.1/32 trust" >> /var/lib/pgsql/data/pg_hba.conf
    echo "host all all ::1/128 trust" >> /var/lib/pgsql/data/pg_hba.conf

    sed -i 's/Hostname=Zabbix proxy/Hostname=proxy/g' /etc/zabbix/zabbix_proxy.conf
    # 192.168.56.130 - zabbix server - not proxy!
    sed -i 's/Server=127.0.0.1/Server=192.168.56.130/g' /etc/zabbix/zabbix_proxy.conf
    sed -i 's/DBName=zabbix_proxy/DBName=zabbix/g' /etc/zabbix/zabbix_proxy.conf
    sed -i 's/DBUser=zabbix/DBUser=zabbix/g' /etc/zabbix/zabbix_proxy.conf
    sed -i 's/# DBPassword=/DBPassword=zabbix/g' /etc/zabbix/zabbix_proxy.conf
    sed -i 's/# DBPort=/DBPort=5432/g' /etc/zabbix/zabbix_proxy.conf


    # enable and start zabbix proxy
    systemctl enable zabbix-proxy && systemctl start zabbix-proxy 
    
    # enable and start pgsql
    systemctl enable postgresql.service && systemctl start postgresql.service

    # create database, user zabbix and grant privileges
    sudo su postgres <<EOF
    psql -c "alter user postgres with password 'zabbix';"
    psql -c "create user zabbix;"
    psql -c "create database zabbix owner zabbix;"
    psql -c "alter user zabbix with password 'zabbix';"
    psql -c "grant all privileges on database zabbix to zabbix;"
EOF

    systemctl restart postgresql.service

    # unzip schema content to postgres
    zcat /usr/share/doc/zabbix-proxy-pgsql-4.0.18/schema.sql.gz | psql -U zabbix -d zabbix

    ;;
  
  #
  ##
  ### CASE "B"
  ##
  #
  b)
    $YUM remove postgresql-server -y
    $YUM remove zabbix-proxy-pgsql -y
    rm -rf /var/lib/pgsql
    ;;
  *)
    echo ""
    echo -e "\t\texiting...."
esac
