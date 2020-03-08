#!/bin/bash

#
##
### Selinux settings
##
#
echo "Checking Selinux status..."
SELINUXSTATUS=$(getenforce)

if [ $SELINUXSTATUS == "Enforcing" ]
 then
  echo -e "Selinux is enabled and during the installation needs to be disabled and put into the permissive mode."
  sed -ie 's/SELINUX=enforcing/SELINUX=permissive/g' /etc/selinux/config
  setenforce 0
else
  echo -e "Selinux is in permissive mode. No action required"
fi