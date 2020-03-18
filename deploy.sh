#!/bin/bash

################################################################################################
# Deploy zabbix proxy with psql db (Postgres)                                                  #
# developed by tmiklu v1.0					                               #
# Still under construction                                                                     #
# 				                                                               #
################################################################################################

clear

echo -e "\n
	 \tWelcome in Zabbix proxy deployment tools \n
         \tThis tools will deploy zabbix proxy to Zabbix master server\n
	 \tTake action, press letter:\n
         \t1. Deploy master Zabbix server (Frontend,backend and PSQL(DB))\n
	 \t2. Deploy fresh Zabbix proxy with psql db\n
         \t3. Remove existing proxy and psql (Dangerous)\n
         \te. Exit\n
	"

read -p $'\t\tEnter your option: ' -n 1 -r USERINPUT

YUM=/usr/bin/yum

case $USERINPUT in

  #
  ##
  ### CASE "2"
  ##
  #
  2) 

    #
    ##
    ### enter name for proxy server
    ##
    #
    read -p "Enter proxy server name for datacenter: " PROXYDC

    #
    ##
    ### selinux
    ##
    #

    #
    ##
    ### requires.sh repo and apps
    ##
    #
    ./requires.sh

    #
    ##
    ### init postgres db store
    ##
    #
    postgresql-setup initdb
    
    # working directory
    cd / 	
    
    # backup config
    echo "backup config to /var/lib/pgsql/data/postgresql.conf.bak"
    cp -pa /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.bak
    

    echo "changing config with sed."
    sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /var/lib/pgsql/data/postgresql.conf
    # pgsql listen on default 5432
    sed -i 's/#port = 5432/port = 5432/g' /var/lib/pgsql/data/postgresql.conf


    # backup pg_hba.conf
    cp -pa /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.orig

    # create config for pg_hba
    cat <<EOF > /var/lib/pgsql/data/pg_hba.conf
    local   all             all                                     trust
    host    all             all             127.0.0.1/32            trust
    host    all             all             ::1/128                 trust
EOF

    cp -pa /etc/zabbix/zabbix_proxy.conf /etc/zabbix/zabbix_proxy.conf.bak

    chmod 0640 /etc/zabbix/zabbix_proxy.conf

    # add zabbix proxy config
cat <<EOF > /etc/zabbix/zabbix_proxy.conf
# use your own zabbix server
Server=192.168.56.130
# case sensitive - same must be on zabbix gui proxy setting
Hostname=${PROXYDC}
LogFile=/var/log/zabbix/zabbix_proxy.log
LogFileSize=0
PidFile=/var/run/zabbix/zabbix_proxy.pid
SocketDir=/var/run/zabbix
DBName=zabbix
DBUser=zabbix
DBPassword=password
DBPort=5432
SNMPTrapperFile=/var/log/snmptrap/snmptrap.log
Timeout=4
ExternalScripts=/usr/lib/zabbix/externalscripts
LogSlowQueries=3000
EOF

    # enable and start zabbix proxy
    systemctl enable zabbix-proxy && systemctl start zabbix-proxy 
    
    # enable and start pgsql
    systemctl enable postgresql.service && systemctl start postgresql.service

    # create database, user zabbix and grant privileges
    sudo su postgres <<EOF
    psql -c "alter user postgres with password 'password';"
    psql -c "create user zabbix;"
    psql -c "create database zabbix owner zabbix;"
    psql -c "alter user zabbix with password 'password';"
    psql -c "grant all privileges on database zabbix to zabbix;"
EOF

    systemctl restart postgresql.service

    # unzip schema content to postgres
    zcat /usr/share/doc/zabbix-proxy-pgsql-4.0.18/schema.sql.gz | psql -U zabbix -d zabbix

    # api auth.
    AUTH=$(curl -s POST -H "Content-Type:application/json" echo http://zabbix.server.com/zabbix/api_jsonrpc.php -d \
    ' {"jsonrpc": "2.0", "method": "user.login", "params": { "user": "Admin", "password": "zabbix" }, "id": 1 }')

    curl -s POST -H "Content-Type:application/json" echo http://zabbix.server.com/zabbix/api_jsonrpc.php -d \
    ' {"jsonrpc": "2.0", "method": "proxy.create", "params": { "host": "'"${PROXYDC}"'", "status": "5" }, "auth": "'${AUTH}'", "id": 1 }'
    ;;
  
  #
  ##
  ### CASE "3"
  ##
  #
  3)
    $YUM remove postgresql-server -y
    $YUM remove zabbix-proxy-pgsql -y
    echo ""
    ;;
  
  #
  ##
  ### CASE "e"
  ##
  #
  e)
    echo ""
    echo -e "\t\texiting...."
    clear
esac
