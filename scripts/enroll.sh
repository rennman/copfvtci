#!/bin/bash
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
COPEXEC="$COP/bin/cop"
TESTDATA="$COP/testdata"
SCRIPTDIR="$COP/scripts"
HOST="http://localhost:8888"
RC=0

while getopts "du:p:t:l:x:" option; do
  case "$option" in
     x)   COP_HOME="$OPTARG" ;;
     d)   COP_DEBUG="true" ;;
     u)   USERNAME="$OPTARG" ;;
     p)   USERPSWD="$OPTARG" ;;
     t)   KEYTYPE="$OPTARG" ;;
     l)   KEYLEN="$OPTARG" ;;
  esac
done

test -z "$COP_HOME" && COP_HOME="$HOME/cop"
test -z "$CLIENTCERT" && CLIENTCERT="$COP_HOME/cert.pem"
test -z "$CLIENTKEY" && CLIENTKEY="$COP_HOME/key.pem"
test -f "$COP_HOME" || mkdir -p $COP_HOME
: ${COP_DEBUG="false"}
: ${USERNAME="admin"}
: ${USERPSWD="adminpw"}
: ${KEYTYPE="ecdsa"}
: ${KEYLEN="256"}

test "$KEYTYPE" = "ecdsa" && sslcmd="ec"

$COPEXEC client enroll $USERNAME $USERPSWD $HOST <(echo "{
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
if $($COP_DEBUG); then 
   echo CERT:
   openssl x509 -in $CLIENTCERT -text 2>&1 | sed 's/^/    /'
   type=$(cat $CLIENTKEY | head -n1 | awk '{print tolower($2)}')
   echo KEY:
   openssl $type -in $CLIENTKEY -text 2>/dev/null| sed 's/^/    /'
fi
exit $RC
