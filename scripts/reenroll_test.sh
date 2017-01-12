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
   test -d $COP_HOME || mkdir -p $COP_HOME
   $SCRIPTDIR/enroll.sh -u $USERNAME -p $PASSWD -x $COP_HOME
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
test -d $COP_HOME || mkdir -p $COP_HOME

for driver in sqlite3 postgres mysql; do
   echo ""
   echo ""
   echo ""
   echo "------> BEGIN TESTING $driver <----------"
   $SCRIPTDIR/cop_setup.sh -R -x $KEYSTORE 
   $SCRIPTDIR/cop_setup.sh -D -I -S -X -n4 -d $driver -x $KEYSTORE
   if test $? -ne 0; then
      echo "Failed to setup server"
      RC=$((RC+1))
      continue
   fi


   COP_HOME=$KEYSTORE/admin
   $SCRIPTDIR/enroll.sh -u admin -p adminpw -x $COP_HOME
   if test $? -ne 0; then
      echo "Failed to enroll admin"
      RC=$((RC+1))
      continue
   fi
   
   for i in {1..4}; do
      enrollUser user${i}
      if test $? -ne 0; then 
         echo "Failed to enroll user${i}"
      else 
         $SCRIPTDIR/reenroll.sh -x $COP_HOME
         if test $? -ne 0; then 
            echo "Failed to reenroll user${i}"
            RC=$((RC+1))
         fi
      fi         
      sleep 1
   done

   $SCRIPTDIR/reenroll.sh -x /tmp/keyStore/admin
   $SCRIPTDIR/reenroll.sh -x /tmp/keyStore/admin
   $SCRIPTDIR/reenroll.sh -x /tmp/keyStore/admin

   for s in {1..4}; do
      curl -s http://${HOST}/ | awk -v s="server${s}" '$0~s'|html2text|grep HTTP
      verifyServerTraffic $HOST server${s} 4
      if test $? -ne 0; then
         echo "Distributed traffic to server FAILED"
         RC=$((RC+1))
      fi
      sleep 1
   done
   echo "------> END TESTING $driver <----------"
   echo "***************************************"
   echo ""
   echo ""
   echo ""
   echo ""

   $SCRIPTDIR/cop_setup.sh -R -x $KEYSTORE
done
CleanUp $RC
exit $RC
