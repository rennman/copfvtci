#!/bin/bash
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
SCRIPTDIR="$COP/scripts" 
. $SCRIPTDIR/cop_utils
RC=0
HOST="localhost:10888"

for driver in sqlite3 postgres mysql; do
   $SCRIPTDIR/cop_setup.sh -R
   $SCRIPTDIR/cop_setup.sh -D -I -S -X -n4 -t rsa -l 2048 -d $driver
   test $? -ne 0 && ErrorExit "Failed to setup server"
   $SCRIPTDIR/registerAndEnroll.sh -u 'user1 user2 user3 user4 user5 user6 user7 user8 user9'
   RC=$((RC+$?))
   $SCRIPTDIR/reenroll.sh -x /tmp/keyStore/admin
   for s in 1 2 3 4; do
      curl -s http://${HOST}/ | awk -v s="server${s}" '$0~s'|html2text | egrep "HTTP|server${s}"
      verifyServerTraffic $HOST server${s} 5
      RC=$((RC+$?))
   done
   $SCRIPTDIR/cop_setup.sh -R
done
CleanUp $RC
exit $RC
