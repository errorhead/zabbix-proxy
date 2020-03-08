#!/bin/bash

#
##
### Required all repositories and apps
##
#

YUM=/usr/bin/yum

echo -e "-------> let's update repos"
$YUM update -y > /dev/null

# add repo for zabbix LTS 4.0
REPOZABBIX=$(yum repolist enabled | grep -Po 'zabbix\/x86\_64' | wc -l)

if [ $REPOZABBIX -eq 1 ] 
 then
  echo "Repo zabbix exists..."
else
  echo "Adding repo zabbix LTS 4.0"
  rpm -Uvh https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-2.el7.noarch.rpm
fi
        
# add repo for psql
REPOPSQL=$(yum repolist | grep -iPo 'pgdg96')
if [ $REPOPSQL -eq 1 ]
 then
 echo "Repo pgsql exists..."
else
 echo "Adding repo psql..."
 $YUM install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm -y
 fi
    
# install proxy-pgsql
ZABBIXPROXY=$(rpm -qa | grep -P 'zabbix\-proxy\-pgsql\-4\.0\.18\-1\.el7\.x86\_64' | wc -l)

if [ $ZABBIXPROXY -eq 1 ]
 then
  echo -e "Installed =$(rpm -qa | grep -P 'zabbix\-proxy\-pgsql\-4\.0\.18\-1\.el7\.x86\_64')"
else
  echo -e "Installing zabbix-proxy-pgsql..."
  $YUM install zabbix-proxy-pgsql-4.0.18-1.el7.x86_64 -y
fi

# install postgres server 
POSTGRESSERVER=$(rpm -qa | grep -P 'postgresql\-server\-9\.2\.24\-2\.el7\_7\.x86\_64' | wc -l)
      
if [ $POSTGRESSERVER -eq 1 ]
 then
  echo -e "Installed $(rpm -qa | grep -P 'postgresql\-server\-9\.2\.24\-2\.el7\_7\.x86\_64')" 
else
  echo -e "Installing..."
  $YUM install postgresql-server -y
fi

# add epel release
EPELREPO=$(yum repolist | grep -i 'Extra Packages for Enterprise Linux')

if [ $EPELREPO -eq 1 ]
 then
  echo -e "Epel repo exists..."
else
  echo -e "Adding Repo Epel"
  $YUM install epel-release -y
fi

# install jq from epel release
$YUM install jq -y