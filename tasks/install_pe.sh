#!/bin/bash

if [ -z ${PT_version+x} ]; then
  PE_RELEASE=2019.8

else
  PE_RELEASE=$PT_version
fi

if [ -z ${PT_os+x} ]; then
  PE_OS=el-7-x86_64

else
  PE_OS=$PT_os
fi

PE_LATEST=$(curl https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/"${PE_RELEASE}"/ci-ready/LATEST)
PE_FILE_NAME=puppet-enterprise-${PE_LATEST}-${PE_OS}
TAR_FILE=${PE_FILE_NAME}.tar
DOWNLOAD_URL=https://artifactory.delivery.puppetlabs.net/artifactory/generic_enterprise__local/${PE_RELEASE}/ci-ready/${TAR_FILE}

## Download PE
if ! curl -o "${TAR_FILE}" "${DOWNLOAD_URL}" ; then
 echo "Error: failed to download [${DOWNLOAD_URL}]"
 exit 2
fi

## Install PE
if ! tar xvf "${TAR_FILE}" ; then
 echo "Error: Failed to untar [${TAR_FILE}]"
 exit 2
fi

cd "${PE_FILE_NAME}" || exit 1
if ! DISABLE_ANALYTICS=1 ./puppet-enterprise-installer -y -c ./conf.d/pe.conf ; then
 echo "Error: Failed to install Puppet Enterprise. Please check the logs and call Bryan.x"
 exit 2
fi

## Finalize configuration
echo "Finalize PE install"
puppet agent -t
# if [[ $? -ne 0 ]];then
#  echo “Error: Agent run failed. Check the logs above...”
#  exit 2
# fi

## Create and configure Certs
echo "autosign = true" >> /etc/puppetlabs/puppet/puppet.conf

service pe-puppetserver restart
