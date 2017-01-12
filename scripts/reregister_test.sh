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
   OUT=$($SCRIPTDIR/register.sh -u $USERNAME -t $USERTYPE -g $USERGRP)
   echo "$OUT"
   PASSWD="$(echo $OUT | tail -n1 | awk '{print $NF}')"
   export COP_HOME=$KEYSTORE/$USERNAME
   $SCRIPTDIR/enroll.sh -u $USERNAME -p $PASSWD
}

function enrollUser() {
   local USERNAME=$1
   mkdir -p $KEYSTORE/$USERNAME
   export COP_HOME=$KEYSTORE/admin
   OUT=$($SCRIPTDIR/register.sh -u $USERNAME -t $USERTYPE -g $USERGRP)
   echo "$OUT"
   PASSWD="$(echo $OUT | tail -n1 | awk '{print $NF}')"
   export COP_HOME=$KEYSTORE/$USERNAME
   $SCRIPTDIR/enroll.sh -u $USERNAME -p $PASSWD
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

for driver in sqlite3 postgres mysql; do
   $SCRIPTDIR/cop_setup.sh -R -x $KEYSTORE
   $SCRIPTDIR/cop_setup.sh -D -I -S -X -n4 -t rsa -l 2048 -d $driver -x $KEYSTORE
   RC=$((RC+$?))

   $SCRIPTDIR/enroll.sh -u admin -p adminpw
   if test $? -ne 0; then
      echo "Failed to enroll admin"
      RC=$((RC+1))
      continue
   fi
   

   $SCRIPTDIR/register.sh -u ${USERNAME} -t $USERTYPE -g $USERGRP
   if test $? -ne 0; then
      echo "Failed to register $USERNAME"
      RC=$((RC+1))
      continue
   fi

   for i in {2..8}; do 
      $SCRIPTDIR/register.sh -u $USERNAME -t $USERTYPE -g $USERGRP
      if test $? -eq 0; then 
         echo "Duplicate registration of " $USERNAME
         RC=$((RC+1))
      fi
   done

   for s in {1..4}; do
      verifyServerTraffic $HOST server${s} 10 "" "" lt
      RC=$((RC+$?))
      sleep 1
   done

   $SCRIPTDIR/cop_setup.sh -R -x $KEYSTORE
done
CleanUp "$RC"
exit $RC
