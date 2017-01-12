#!/bin/bash
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
SCRIPTDIR="$COP/scripts"
KEYSTORE="/tmp/keyStore"
RC=0

. $SCRIPTDIR/cop_utils

function enrollUser() {
   local USERNAME=$1
   mkdir -p $KEYSTORE/$USERNAME
   export COP_HOME=$KEYSTORE/admin
   OUT=$($SCRIPTDIR/register.sh -u $USERNAME -t $USERTYPE -g $USERGRP -x $COP_HOME)
   echo "$OUT"
   PASSWD="$(echo "$OUT" | head -n1 | awk '{print $NF}')"
   export COP_HOME=$KEYSTORE/$USERNAME
   $SCRIPTDIR/enroll.sh -u $USERNAME -p $PASSWD -x $COP_HOME
   rc=$?
   return $rc
}

while getopts "du:t:k:l:" option; do
  case "$option" in
     d)   COP_DEBUG="true" ;;
     u)   USERNAME="$OPTARG" ;;
     t)   USERTYPE="$OPTARG" ;;
     g)   USERGRP="$OPTARG" ;;
     k)   KEYTYPE="$OPTARG" ;;
     l)   KEYLEN="$OPTARG" ;;
  esac
done

: ${COP_DEBUG="false"}
: ${USERNAME="newclient"}
: ${USERTYPE="client"}
: ${USERGRP="bank_a"}
: ${KEYTYPE="ecdsa"}
: ${KEYLEN="256"}
: ${HOST="localhost:10888"}

export COP_DEBUG
mkdir -p $KEYSTORE/admin
export COP_HOME=$KEYSTORE/admin
$SCRIPTDIR/enroll.sh -u admin -p adminpw -x $COP_HOME
test $? -eq 0 || ErrorExit "Failed to enroll admin"

for i in $USERNAME; do
   enrollUser $i
   RC=$((RC+$?))
   sleep 1
done

exit $RC
