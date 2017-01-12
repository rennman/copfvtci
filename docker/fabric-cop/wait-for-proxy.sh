#!/bin/sh
timeout=10
#start=$(date "+%s")
cmd='/usr/local/bin/cop client enroll admin adminpw http://haproxy:8888 /etc/hyperledger/fabric-cop/csr.json' 
#until nc haproxy:8880 -e echo success;do 
#   test "$time" -gt "$timeout" && break
#   >&2 echo "database unavailable - sleeping"
#   sleep 1
#   now=$(date "+%s")
#   time=$((now-start))
#done
#>&2 echo "database available - starting cop"
sleep $timeout
exec $cmd

