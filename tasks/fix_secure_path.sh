#!/bin/bash

if [ -z "${PT_path}" ] ; then
  pupt_path="/opt/puppetlabs/bin"
else
  pupt_path=$PT_path
fi

sed -i -r -e "/^\s*Defaults\s*secure_path\s*/ s#=+\"([^\"]+)\".*#=\"\1:${pupt_path}\"#" /etc/sudoers
sed -i -r -e "/^\s*Defaults\s+secure_path/ s#=([^\"].*)#=\1:${pupt_path}#" /etc/sudoers

exit 0
