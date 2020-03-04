#!/bin/bash

################################################################################################
# Deploy zabbix proxy with psql db (Postgres)   					                           #
# developed by tmiklu v1.0								                                       #
# created for Descartes systems  				                                               #
################################################################################################

clear

echo -e "\n
	     \tWelcome in Zabbix proxy deployment tools \n
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
	
	# backup config
    echo "backup config to /var/lib/pgsql/data/postgresql.conf.bak"
    cp -pa /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.bak

	echo "changing config with sed."
    sed -ie "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
    sed -ie 's/#port = 5432/port = 5432/g' /var/lib/pgsql/data/postgresql.conf

    # enable and start zabbix proxy
    systemctl enable zabbix-proxy && systemctl start zabbix-proxy 
    
    # enable and start pgsql
    systemctl enable postgresql.service && systemctl start postgresql.service

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
