#!/bin/bash
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
COPEXEC="$COP/bin/cop"
TESTDATA="$COP/testdata"
SCRIPTDIR="$COP/scripts"
. $SCRIPTDIR/cop_utils
HOST="http://localhost:8888"
RC=0

while getopts "du:p:t:l:x:" option; do
  case "$option" in
     d)   COP_DEBUG="true" ;;
     x)   COP_HOME="$OPTARG" ;;
     u)   USERNAME="$OPTARG" ;;
     p)   USERPSWD="$OPTARG"
          test -z "$USERPSWD" && AUTH=false
     ;;
     t)   KEYTYPE="$OPTARG" ;;
     l)   KEYLEN="$OPTARG" ;;
  esac
done

test -z "$COP_HOME" && COP_HOME="$HOME/cop"
test -z "$CLIENTCERT" && CLIENTCERT="$COP_HOME/cert.pem"
test -z "$CLIENTKEY" && CLIENTKEY="$COP_HOME/key.pem"
test -f "$COP_HOME" || mkdir -p $COP_HOME
: ${COP_DEBUG="false"}
: ${AUTH="true"}
: ${USERNAME="admin"}
: ${USERPSWD="adminpw"}
$($AUTH) || unset USERPSWD
: ${KEYTYPE="ecdsa"}
: ${KEYLEN="256"}

test "$KEYTYPE" = "ecdsa" && sslcmd="ec"

$COPEXEC client enroll "$USERNAME" "$USERPSWD" "$HOST" <(echo "{
    \"hosts\": [
        \"admin@fab-client.raleigh.ibm.com\",
        \"fab-client.raleigh.ibm.com\",
        \"127.0.0.2\"
    ],
    \"CN\": \"$USERNAME\",
    \"key\": {
        \"algo\": \"$KEYTYPE\",
        \"size\": $KEYLEN
    },
    \"names\": [
        {
            \"SerialNumber\": \"$USERNAME\",
            \"O\": \"Hyperledger\",
            \"O\": \"Fabric\",
            \"OU\": \"COP\",
            \"OU\": \"FVT\",
            \"STREET\": \"Miami Blvd.\",
            \"DC\": \"peer\",
            \"UID\": \"admin\",
            \"L\": \"Raleigh\",
            \"L\": \"RTP\",
            \"ST\": \"North Carolina\",
            \"C\": \"US\"
        }
    ]
}")
RC=$?
$($COP_DEBUG) && printAuth $CLIENTCERT $CLIENTKEY 
exit $RC
