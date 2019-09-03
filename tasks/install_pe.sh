#!/bin/bash

PE_RELEASE=2019.2
PE_LATEST=$(curl http://enterprise.delivery.puppetlabs.net/${PE_RELEASE}/ci-ready/LATEST)
PE_FILE_NAME=puppet-enterprise-${PE_LATEST}-el-7-x86_64
TAR_FILE=${PE_FILE_NAME}.tar
DOWNLOAD_URL=http://enterprise.delivery.puppetlabs.net/${PE_RELEASE}/ci-ready/${TAR_FILE}

## Download PE
curl -o ${TAR_FILE} ${DOWNLOAD_URL}
if [[ $? -ne 0 ]];then
 echo “Error: wget failed to download [${DOWNLOAD_URL}]”
 exit 2
fi

## Install PE
tar xvf ${TAR_FILE}
if [[ $? -ne 0 ]];then
 echo “Error: Failed to untar [${TAR_FILE}]”
 exit 2
fi

cd ${PE_FILE_NAME}
DISABLE_ANALYTICS=1 ./puppet-enterprise-installer
if [[ $? -ne 0 ]];then
 echo “Error: Failed to install Puppet Enterprise. Please check the logs and call Bryan.x ”
 exit 2
fi

## Finalize configuration
echo “Finalize PE install”
puppet agent -t
# if [[ $? -ne 0 ]];then
#  echo “Error: Agent run failed. Check the logs above...”
#  exit 2
# fi

## Create and configure Certs
echo "autosign = true" >> /etc/puppetlabs/puppet/puppet.conf

service pe-puppetserver restart
