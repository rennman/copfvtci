#!/bin/bash
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
SCRIPTDIR="$COP/scripts" 
TESTDATA="$COP/testdata"
. $SCRIPTDIR/cop_utils
RC=0
HOST="localhost:10888"

MAX="$1"
: ${MAX:="65"}

# user can only enroll MAX times
$SCRIPTDIR/cop_setup.sh -R
$SCRIPTDIR/cop_setup.sh -I -S -X -m $MAX
export COP_HOME=/tmp/keyStore/admin

i=0
while test $((i++)) -lt "$MAX"; do
   $SCRIPTDIR/enroll.sh -u admin -p adminpw -x /tmp/keyStore/admin
   RC=$((RC+$?))
done

$SCRIPTDIR/enroll.sh -u admin -p adminpw -x /tmp/keyStore/admin
test "$?" -eq 0 && RC=$((RC+1))

CleanUp $RC
exit $RC
