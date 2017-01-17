#!/bin/bash 
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
SCRIPTDIR="$COP/scripts" 
. $SCRIPTDIR/cop_utils
RC=0
HOST="localhost:10888"

#for driver in sqlite3 postgres mysql; do
for driver in sqlite3 ; do

   # - auth enabled
   $SCRIPTDIR/cop_setup.sh -R 
   $SCRIPTDIR/cop_setup.sh -I -S -X -d $driver
   test $? -ne 0 && ErrorExit "Failed to setup server"
   # Success case - send passwd 
   $SCRIPTDIR/enroll.sh -u admin -p adminpw 
   RC=$((RC+$?))
   # Fail case - send null passwd
   $SCRIPTDIR/enroll.sh -u admin -p ""
   test $? -eq 0 && RC=$((RC+1))
   # Fail case - send bogus passwd
   $SCRIPTDIR/enroll.sh -u admin -p xxxxxx
   test $? -eq 0 && RC=$((RC+1))

   # - auth disabled
   $SCRIPTDIR/cop_setup.sh -R
   $SCRIPTDIR/cop_setup.sh -A -I -S -X -d $driver
   # Success case - send correct passwd 
   $SCRIPTDIR/enroll.sh -u admin -p adminpw
   RC=$((RC+$?))
   # Success case - send null passwd 
   $SCRIPTDIR/enroll.sh -u admin -p "" 
   RC=$((RC+$?))
   # Success case - send bogus passwd 
   $SCRIPTDIR/enroll.sh -u admin -p xxxxxx 
   RC=$((RC+$?))

done
CleanUp $RC
exit $RC
