#!/bin/bash

# get parameters provided by bolt
if [ -n "$PT_collection" ]; then
  collection=$PT_collection
else
  collection='none'
fi

if [ -n "$PT_platform" ]; then
  platform=$PT_platform
else
  platform='none'
fi

if [ -n "$PT_retry" ]; then
  retry=$PT_retry
else
  retry=5
fi

parse_platform() {
  data=()
  for x in $(echo "$1" | tr "/|-|-|:" "\n")
  do
    data+=("$x")
  done
  if [[ "$2" == "osname" ]]; then
    if [[ "${data[0]}" == "litmusimage" ]]; then
      echo "${data[1]}"
    else
      echo "${data[0]}"
    fi
  fi
  if [[ "$2" == "majorversion" ]]; then
    if [[ "${data[0]}" == "litmusimage" ]]; then
      echo "${data[2]}"
    else
      echo "${data[1]}"
    fi
  fi
}

fetch_osfamily() {
  re_debian="(^debian|ubuntu)"
  re_redhat="(^redhat|rhel|centos|scientific|oraclelinux)"
  unsupported=1
  if [[ $1 =~ $re_debian ]]; then
    echo "debian"
    unsupported=0
  fi
  if [[ $1 =~ $re_redhat ]]; then
    echo "redhat"
    unsupported=0
  fi
  if [[ $unsupported == 1 ]]; then
    echo "unsupported"
  fi
}

fetch_collection() {
  # Handle puppetcore8-nightly -> puppet8-nightly conversion
  if [[ "$1" == puppetcore8* ]]; then
    echo "${1/puppetcore8/puppet8}"
  else
    myarr=()
    for x in $(echo "$1" | tr "-" "\n")
    do
      myarr+=("$x")
    done
    echo "${myarr[0]}"
  fi
}

fetch_codename() {
  codename="unsupported"
  case $2 in
    "8")
      if [[ "$1" == "puppet6" ]]; then
        codename="jessie"
      fi
      ;;
    "9") codename="stretch";;
    "10") codename="buster";;
    "11") codename="bullseye";;
    "12") codename="bookworm";;
    "1404")
      if [[ "$1" == "puppet6" ]]; then
        codename="trusty"
      fi
      ;;
    "14.04")
      if [[ "$1" == "puppet6" ]]; then
        codename="trusty"
      fi
      ;;
    "1604") codename="xenial";;
    "16.04") codename="xenial";;
    "1804") codename="bionic";;
    "18.04") codename="bionic";;
    "2004") codename="focal";;
    "20.04") codename="focal";;
    "2204") codename="jammy";;
    "22.04") codename="jammy";;
    *) codename="unsupported"
  esac
  echo $codename
}

run_cmd() {
  eval "$1"
  rc=$?

  if test $rc -ne 0; then
    attempt_number=0
    while test $attempt_number -lt "$retry"; do
      echo "Retrying... [$((attempt_number + 1))/$retry]"
      eval "$1"
      rc=$?

      if test $rc -eq 0; then
        break
      fi

      echo "Return code: $rc"
      sleep 1s
      ((attempt_number=attempt_number+1))
    done
  fi

  return $rc
}

if [[ "$platform" == "none" || "$collection" == "none" ]]; then
  echo "please provide both parameters(collection and platform)"
  exit 1
fi

if [[ "$platform" == "null" || "$collection" == "null" ]]; then
  echo "please provide both parameters(collection and platform)"
  exit 1
fi

osname=$(parse_platform "$platform" "osname")
major_version=$(parse_platform "$platform" "majorversion")
osfamily=$(fetch_osfamily "$osname")
# Keep the full collection name (e.g., puppet8-nightly) instead of truncating
# collection=$(fetch_collection "$collection")
collection=$collection

if [[ "$collection" == "puppet5" ]]; then
  echo "puppet5 eol!"
  exit 1
fi

if [[ "$osfamily" == "unsupported" ]]; then
  echo "No builds for $platform"
  exit 1
fi

if [[ "$osfamily" == "debian" ]]; then
  codename=$(fetch_codename "$collection" "$major_version")
  if [[ "$codename" == "unsupported" ]]; then
    echo "No builds for $platform"
    exit 1
  else
    run_cmd "curl -o puppet.deb https://artifactory.delivery.puppetlabs.net:443/artifactory/internal_nightly__local/apt/${collection}-release-${codename}.deb"
    dpkg -i --force-confmiss puppet.deb
    apt-get update -y
    apt-get install puppetserver -y
  fi
fi

if [[ "$osfamily" == "redhat" ]]; then
  run_cmd "curl -o puppet.rpm https://artifactory.delivery.puppetlabs.net:443/artifactory/internal_nightly__local/yum/${collection}-release-el-${major_version}.noarch.rpm"
  rpm -Uvh puppet.rpm --quiet
  yum install puppetserver -y --quiet
fi

exit 0
