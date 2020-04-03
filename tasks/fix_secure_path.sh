#!/bin/bash

pupt_path=${PT_path:-/opt/puppetlabs/bin}

sed -i -r -e "/^\s*Defaults\s*secure_path\s*/ s#=+\"([^\"]+)\".*#=\"\1:${pupt_path}\"#" /etc/sudoers
sed -i -r -e "/^\s*Defaults\s+secure_path/ s#=([^\"].*)#=\1:${pupt_path}#" /etc/sudoers

exit 0
