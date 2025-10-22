#! /bin/sh
#
# trivial script to copy/distribute tcsg4*-style files to
# a target system using rsync, set permissions, and maybe restart 
# some service(s) - applicable to YUM/APT based systems (to be
# set explicitly)
#
# Requirements: sh, ssh, rsync, chmod 
# Remote requirements: yum (or apt), rsync, chmod, chown, (systemctl)
#
# Copyright 2021-2022 David Groep, Nikhef, Amsterdam
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
CPUSER=${CPUSER:-root}

httpdrestart=""
destpath=/root
srcdir=.
destdir=tcsg4
pkgmngr="yum"
keyperms=0600

usage() {
cat <<EOF

Usage: $0 [-R] [-d destdir (tcsg4)] [-p destpath (/root)] [-U user]
          [-s srcdir] [-H] [-S service] [hostname]
  -s dir  source directory for cert files and keys (default: .)
  -d dir  subdirectory on the target that data will be places in
          (default: .../$destdir)
  -p dir  destination top-level path. Defaults to $destpath if
          user is root, the user homedir (e.g. /home/$CPUSER)
          otherwise. -R will overrule this setting
  -R      copy files to the EL-destigated place (/etc/pki/tls/tcsg4)
  -U user use <user> as the userid on the target system (default: $CPUSER)
  -O ownr use <ownr> as the file owner on target system (default: $CPUSER)
  -K keyp set key permissions to <keyp> (default: 0600)
  -A      use apt-get, not yum, to ensure remote rsync is present
  -H      run "systemctl restart httpd" on the target afterwards
  -S srv  run "systemctl restart <srv>" on the target afterwards

EOF
  exit 1;
}


while getopts "s:d:p:RhAHS:U:O:K:" o
do
  case "${o}" in
    U ) CPUSER="${OPTARG}" ;;
    O ) OWNER="${OPTARG}" ;;
    K ) keyperms="${OPTARG}" ;;
    H ) httpdrestart="httpd" ;;
    S ) httpdrestart="${OPTARG}" ;;
    p ) destpath=${OPTARG} ;;
    d ) destdir=${OPTARG} ;;
    R ) destpath=/etc/pki/tls ;;
    A ) pkgmngr=apt ;;
    s ) srcdir=${OPTARG} ;;
    h ) usage ;;
  esac
done
shift $((OPTIND-1))

if [ $CPUSER = root ] ; then
  CPPATH="$destpath"
else
  CPPATH=/home/$CPUSER
fi

c=`ls ${srcdir}/key*pem 2>/dev/null |wc -l`
if [ $c -ne 1 ]; then
  echo "Too many or too few keys here in ${srcdir} - cd into source first" >&2
  exit 1
fi

fn=${1:-`ls -1 ${srcdir}/key-*.pem | sed -e 's/.*key-\(.*\)\.pem/\1/'`}

echo Installing to host $fn

ping -q -w 20 -c 1 $fn > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR: cannot ping $fn" >&2
  exit 1
fi

if [ $CPUSER = root ]; then
  echo "Installing rsync using $pkgmngr ..."
  if [ $pkgmngr = yum ]; then
    ssh $CPUSER@"$fn" "rsync --help > /dev/null 2>&1 || yum -y install rsync > /dev/null 2>&1"
  elif [ $pkgmngr = apt ]; then
    ssh $CPUSER@"$fn" "rsync --help > /dev/null 2>&1 || ( apt-get update && apt-get install rsync ) > /dev/null 2>&1"
  else
    echo "Don't know package management system $pkgmngr" >&2 
    exit 2
  fi
else
  echo "Not a root user - not installing rsync"
fi

echo "mkdir -p $CPPATH/$destdir/"
ssh $CPUSER@"$fn" "mkdir -p $CPPATH/$destdir/"

echo "rsync ${srcdir}/ to ${CPUSER}@"$fn":$CPPATH/$destdir/ ..."
rsync -rav ${srcdir}/ ${CPUSER}@"$fn":$CPPATH/$destdir/

OWNER=${OWNER:-"$CPUSER:$CPUSER"}

echo "setting $keyperms ($OWNER) permissions on $CPPATH/$destdir/key\* ..."
ssh ${CPUSER}@"$fn" "chmod $keyperms $CPPATH/$destdir/key* ; chmod $keyperms $CPPATH/$destdir/*.p12 ; chown -R $OWNER $CPPATH/$destdir"

if [ "$httpdrestart" != "" ]; then
  if [ $CPUSER = root ]; then
    echo "Running systemctl restart $httpdrestart as ${CPUSER}@$fn"
    ssh ${CPUSER}@"$fn" "systemctl restart $httpdrestart"
  else
    echo "***"
    echo "*** WARNING: target user is not root, but $CPUSER - will NOT RESTART anything" >&2
    echo "***"
  fi
fi

