# !/bin/bash -x
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
COPEXEC="$COP/bin/cop"
TESTDATA="$COP/testdata"
SCRIPTDIR="$COP/scripts"
CSR="$TESTDATA/csr.json"
HOST="http://localhost:8888"
RUNCONFIG="$TESTDATA/postgres.json"
INITCONFIG="$TESTDATA/csr_ecdsa256.json"
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
CLIENTCERT="$COP_HOME/cert.pem"
CLIENTKEY="$COP_HOME/key.pem"
export COP_HOME
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
$($COP_DEBUG) && printAuth $CLIENTCERT $CLIENTKEY
exit $RC
