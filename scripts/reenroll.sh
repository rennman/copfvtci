#!/bin/bash
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
COPEXEC="$COP/bin/cop"
TESTDATA="$COP/testdata"
SCRIPTDIR="$COP/scripts"
CSR="$TESTDATA/csr.json"
HOST="http://localhost:8888"
RUNCONFIG="$TESTDATA/postgres.json"
INITCONFIG="$TESTDATA/csr_ecdsa256.json"
#INITCONFIG="$TESTDATA/csr_dsa.json"
# RUNCONFIG="$TESTDATA/testconfig.json"
COP_HOME="$HOME/cop"
CLIENTCERT="$DATADIR/cert.pem"
CLIENTKEY="$DATADIR/key.pem"
RC=0

: ${COP_DEBUG="false"}

while getopts "k:l:x:" option; do
  case "$option" in
     x)   COP_HOME="$OPTARG" ;;
     k)   KEYTYPE="$OPTARG" ;;
     l)   KEYLEN="$OPTARG" ;;
  esac
done

: ${KEYTYPE="ecdsa"}
: ${KEYLEN="256"}
: ${COP_DEBUG="false"}
test -z "$COP_HOME" && COP_HOME=$HOME/cop

$COPEXEC client reenroll $HOST <(echo "{
    \"hosts\": [
        \"admin@fab-client.raleigh.ibm.com\",
        \"fab-client.raleigh.ibm.com\",
        \"127.0.0.2\"
    ],
    \"key\": {
        \"algo\": \"$KEYTYPE\",
        \"size\": $KEYLEN
    },
    \"names\": [
        {
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
   if test "$RC" -eq 0; then
      echo CERT:
      openssl x509 -in $CLIENTCERT -text 2>&1 | sed 's/^/    /'
      ktype=$(cat $CLIENTKEY | head -n1 | awk '{print tolower($2)}')
      echo KEY:
      openssl $ktype -in $CLIENTKEY -text 2>/dev/null| sed 's/^/    /'
   fi
fi
exit $RC
