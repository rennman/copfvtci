#!/bin/bash
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
COPEXEC="$COP/bin/cop"
TESTDATA="$COP/testdata"
SCRIPTDIR="$COP/scripts"
HOST="http://localhost:8888"
RC=0

while getopts "u:t:g:a:x:" option; do
  case "$option" in
     x)   DATADIR="$OPTARG" ;;
     u)   USERNAME="$OPTARG" ;;
     t)   USERTYPE="$OPTARG" ;;
     g)   USERGRP="$OPTARG" ;;
     a)   USERATTR="$OPTARG" ;;
  esac
done

test -z $DATADIR && DATADIR="$HOME/.cop"
CLIENTCERT=$DATADIR/cert.pem
CLIENTKEY=$DATADIR/key.pem

: ${USERNAME:="testuser"}
: ${USERTYPE:="client"}
: ${USERGRP:="bank_a"}
: ${USERATTR:='[{"name":"test","value":"testValue"}]'}
: ${COP_DEBUG="false"}

$COPEXEC client register <(echo "{
  \"id\": \"$USERNAME\",
  \"type\": \"$USERTYPE\",
  \"group\": \"$USERGRP\",
  \"attrs\": $USERATTR }") $HOST
RC=$?
if $($COP_DEBUG); then 
   if test "$RC" -eq 0; then
      echo CERT:
      openssl x509 -in $CLIENTCERT -text 2>&1 | sed 's/^/    /'
      ktype=$(cat $CLIENTKEY | head -n1 | awk '{print tolower($2)}')
      echo KEY:
      openssl $ktype -in $CLIENTKEY -text 2>/dev/null| sed 's/^/    /'
   fi
fi
exit $RC
