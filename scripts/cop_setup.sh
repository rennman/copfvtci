#!/bin/bash
COP="${GOPATH}/src/github.com/hyperledger/fabric-cop"
COPEXEC="$COP/bin/cop"
TESTDATA="$COP/testdata"
RUNCONFIG="$TESTDATA/runCopFvt.json"
INITCONFIG="$TESTDATA/initCopFvt.json"
DST_KEY="$TESTDATA/cop-key.pem"
DST_CERT="$TESTDATA/cop-cert.pem"
MYSQL_PORT="3306"
POSTGRES_PORT="5432"
GO_VER="1.7.1"
ARCH="amd64"
RC=0

function ErrorExit() {
   echo "${1}...exiting"
   exit 1
}

function tolower() {
  echo "$1" | tr [:upper:] [:lower:]
}

function genRunconfig() {
   cat > $RUNCONFIG <<EOF
{
 "tls_disable":true,
 "authentication": true,
 "driver":"$DRIVER",
 "data_source":"$DATASRC",
 "ca_cert":"$TESTDATA/ec.pem",
 "ca_key":"$TESTDATA/ec-key.pem",
 "users": {
    "admin": {
      "pass": "adminpw",
      "type": "client",
      "group": "bank_a",
      "attrs": [{"name":"hf.Registrar.Roles","value":"client,peer,validator,auditor"},
                {"name":"hf.Registrar.DelegateRoles", "value": "client"},
                {"name":"hf.Revoker", "value": "true"}]
    },
    "admin2": {
      "pass": "adminpw2",
      "type": "client",
      "group": "bank_a",
      "attrs": [{"name":"hf.Registrar.Roles","value":"client,peer,validator,auditor"},
                {"name":"hf.Registrar.DelegateRoles", "value": "client"},
                {"name":"hf.Revoker", "value": "true"}]
    },
    "revoker": {
      "pass": "revokerpw",
      "type": "client",
      "group": "bank_a",
      "attrs": [{"name":"hf.Revoker", "value": "true"}]
    },
    "notadmin": {
      "pass": "pass",
      "type": "client",
      "group": "bank_a",
      "attrs": [{"name":"hf.Registrar.Roles","value":"client,peer,validator,auditor"},
                {"name":"hf.Registrar.DelegateRoles", "value": "client"}]
    },
    "testUser": {
      "pass": "user1",
      "type": "client",
      "group": "bank_a",
      "attrs": []
    },
    "testUser2": {
      "pass": "user2",
      "type": "client",
      "group": "bank_a",
      "attrs": []
    },
    "testUser3": {
      "pass": "user3",
      "type": "client",
      "group": "bank_a",
      "attrs": []
    }
 },
 "groups": {
   "banks_and_institutions": {
     "banks": ["bank_a", "bank_b", "bank_c"],
     "institutions": ["institution_a"]
   }
 },
 "signing": {
    "default": {
       "usages": ["cert sign"],
       "expiry": "8000h",
       "crl_url": "http://swlinux/certs/PKI/CAs/TSCP1100CA16C/crl/crl.der",
       "ca_constraint": {"is_ca": true, "max_path_len":1},
       "ocsp_no_check": true,
       "not_before": "2016-12-30T00:00:00Z"
    }
 }
}
EOF
}

function genInitConfig() {
   cat > $INITCONFIG <<EOF
{
 "hosts": [
     "eca@127.0.0.1"
 ],
 "CN": "FVT COP Enrollment CA($KEYTYPE $KEYLEN)",
 "key": {
     "algo": "$KEYTYPE",
     "size": $KEYLEN
 },
 "names": [
     {
         "SN": "admin",
         "O": "Hyperledger",
         "O": "Fabric",
         "OU": "COP",
         "OU": "FVT",
         "STREET": "Miami Blvd.",
         "DC": "peer",
         "UID": "admin",
         "L": "Raleigh",
         "L": "RTP",
         "ST": "North Carolina",
         "C": "US"
     }
 ]
}
EOF
}

function usage() {
   echo "ARGS:"
   echo "  -d)   <DRIVER> - [sqlite3|mysql|postgres]"
   echo "  -n)   <COP_INSTANCES> - number of servers to start"
   echo "  -i)   <GITID> - ID for cloning git repo"
   echo "  -t)   <KEYTYPE> - rsa|ecdsa"
   echo "  -l)   <KEYLEN> - ecdsa: 256|384|521; rsa 2048|3072|4096"
   echo "  -c)   <SRC_CERT> - pre-existing server cert"
   echo "  -k)   <SRC_KEY> - pre-existing server key"
   echo "  -x)   <DATADIR> - local storage for client auth_info"
   echo "FLAGS:"
   echo "  -D)   set COP_DEBUG='true'"
   echo "  -R)   set RESET='true' - delete DB, server certs, client certs"
   echo "  -P)   set PREP='true'  - install mysql, postgres, pq"
   echo "  -C)   set CLONE='true' - clone fabric-cop repo"
   echo "  -B)   set BUILD='true' - build cop server"
   echo "  -I)   set INIT='true'  - run cop server init"
   echo "  -S)   set START='true' - start \$COP_INSTANCES number of servers"
   echo "  -X)   set PROXY='true' - start haproxy for \$COP_INSTANCES of cop servers"
   echo "  -K)   set KILL='true'  - kill all running cop instances and haproxy"
   echo "  -L)   list all running cop instances"
   echo " ?|h)  this help text"
   echo ""
   echo "Defaults: -d sqlite3 -n 1 -k ecdsa -l 256"
}

function runPSQL() {
   cmd="$1"
   opts="$2"
   wrk_dir="$(pwd)"
   cd /tmp
   sudo -u postgres psql "$opts" -c "$cmd"
   cd $wrk_dir
}

function updateBase {
   sudo apt-get update
   sudo apt-get -y upgrade
   sudo apt-get -y autoremove
   return $?
}

function installGolang {
   local rc=0
   curl -G -L https://storage.googleapis.com/golang/go${GO_VER}.linux-${ARCH}.tar.gz \
           -o /tmp/go${GO_VER}.linux-${ARCH}.tar.gz
   sudo tar -C /usr/local -xzf /tmp/go${GO_VER}.linux-${ARCH}.tar.gz
   let rc+=$?
   sudo apt-get install -y golang-golang-x-tools
   let rc+=$?
   return $rc
}

function installDocker {
   local rc=0
   local codename=$(lsb_release -c | awk '{print $2}')
   local kernel=$(uname -r)
   sudo apt-get install apt-transport-https ca-certificates \
                linux-image-extra-$kernel linux-image-extra-virtual
   sudo echo "deb https://apt.dockerproject.org/repo ubuntu-${codename} main" >/tmp/docker.list
   sudo cp /tmp/docker.list /etc/apt/sources.list.d/docker.list
   sudo apt-key adv --keyserver hkp://ha.pool.sks-keyservers.net:80 \
                    --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
   sudo apt-get update
   sudo apt-get -y upgrade
   sudo apt-get -y install docker-engine || let rc+=1
   sudo curl -L https://github.com/$(curl -s -L https://github.com/docker/compose/releases | awk -v arch=$(uname -s)-$(uname -p) -F'"' '$0~arch {print $2;exit}') -o /usr/local/bin/docker-compose
   sudo chmod +x /usr/local/bin/docker-compose
   sudo groupadd docker
   sudo usermod -aG docker $(who are you | awk '{print $1}')
   return $rc
}

function updateSudoers() {
   local tmpfile=/tmp/sudoers
   local rc=0
   sudo cp /etc/sudoers $tmpfile
   echo 'ibmadmin ALL=(ALL) NOPASSWD:ALL' | tee -a $tmpfile
   sudo uniq $tmpfile | sudo tee $tmpfile
   sudo visudo -c -f $tmpfile  
   test "$?" -eq "0" && sudo cp $tmpfile /etc/sudoers || rc=1
   sudo rm -f $tmpfile
   return $rc
}

function installPrereq() {
   updateBase || ErrorExit "updateBase failed"
   updateSudoers || ErrorExit "updateSudoers failed"
   installGolang || ErrorExit "installGolang failed"
   installDocker || ErrorExit "installDocker failed"
   go get github.com/go-sql-driver/mysql || ErrorExit "install go-sql-driver failed"
   go get github.com/lib/pq || ErrorExit "install pq failed"
   sudo apt-get -y install haproxy postgresql postgresql-contrib \
                   vim-haproxy haproxy-doc postgresql-doc locales-all \
                   libdbd-pg-perl isag jq git || ErrorExit "haproxy installed failed"
   export DEBIAN_FRONTEND=noninteractive
   sudo apt-get -y purge mysql-server
   sudo apt-get -y purge mysql-server-core
   sudo apt-get -y purge mysql-common
   sudo apt-get -y install debconf-utils zsh htop
   sudo rm -rf /var/log/mysql
   sudo rm -rf /var/log/mysql.*
   sudo rm -rf /var/lib/mysql
   sudo rm -rf /etc/mysql
   sudo echo "mysql-server mysql-server/root_password password mysql" | sudo debconf-set-selections
   sudo echo "mysql-server mysql-server/root_password_again password mysql" | sudo debconf-set-selections
   sudo apt-get install -y mysql-client mysql-common \
                           mysql-server --fix-missing --fix-broken || ErrorExit "install mysql failed"
   sudo apt -y autoremove
   runPSQL "ALTER USER postgres WITH PASSWORD 'postgres';"
}

function cloneCop() {
   test -d ${GOPATH}/src/github.com/hyperledger || mkdir -p ${GOPATH}/src/github.com/hyperledger
   cd ${GOPATH}/src/github.com/hyperledger
   git clone http://gerrit.hyperledger.org/r/fabric-cop || ErrorExit "git clone of fabric-cop failed"
}

function buildCop(){
   cd $COP
   make cop || ErrorExit "buildCop failed"
}

function resetCop(){
   killAllCops
   rm -rf $DATADIR
   rm $TESTDATA/cop.db
   cd /tmp
   sudo -u postgres dropdb cop
   sudo mysql --host=localhost --user=root --password=mysql -e 'DROP DATABASE IF EXISTS cop;'
}

function listCop(){
   echo "Listening servers;" 
   lsof -n -i tcp:9888


   case $DRIVER in 
      mysql)
         echo ""
         mysql --host=localhost --user=root --password=mysql -e 'show tables' cop
         echo "Users:" 
         mysql --host=localhost --user=root --password=mysql -e 'SELECT * FROM "users";' cop
      ;;
      postgres) 
         echo ""
         runPSQL '\l cop' | sed 's/^/   /;1s/^ *//;1s/$/:/'

         echo "Users:" 
         runPSQL 'SELECT * FROM "users";' '--dbname=cop' | sed 's/^/   /'
      ;;
   esac
}

function initCop() {
   test -f $COPEXEC || ErrorExit "cop executable not found (use -B to build)"
   cd $COP/bin
 
   genInitConfig
   export COP_HOME=$HOME/cop
   $COPEXEC server init $INITCONFIG

   cp $SRC_KEY $DST_KEY
   cp $SRC_CERT $DST_CERT
   echo "COP server initialized"
   if $($COP_DEBUG); then
      openssl x509 -in $DST_CERT -noout -issuer -subject -serial \
                   -dates -nameopt RFC2253| sed 's/^/   /'
      openssl x509 -in $DST_CERT -noout -text |
         awk '
            /Subject Alternative Name:/ {
               gsub(/^ */,"")
               printf $0"= "
               getline; gsub(/^ */,"")
               print
            }'| sed 's/^/   /'
      openssl x509 -in $DST_CERT -noout -pubkey |
         openssl $KEYTYPE -pubin -noout -text 2>/dev/null| sed 's/Private/Public/'
      openssl $KEYTYPE -in $DST_KEY -text 2>/dev/null
   fi
}


function startHaproxy() {
   local inst=$1
   local i=0
   sudo /etc/init.d/haproxy stop
   #sudo sed -i 's/ *# *$UDPServerRun \+514/$UDPServerRun 514/' /etc/rsyslog.conf
   #sudo sed -i 's/ *# *$ModLoad \+imudp/$ModLoad imudp/' /etc/rsyslog.conf
   haproxy -f  <(echo "global
      #log localhost local0 debug
      log /dev/log	local0 debug
      log /dev/log	local1 debug
      daemon
defaults
      log     global
      mode http
      option  httplog
      option  dontlognull
      maxconn 1024
      timeout connect 5000
      timeout client 50000
      timeout server 50000
      option forwardfor

listen stats
      bind *:10888
      stats enable
      stats uri /
      stats enable

frontend haproxy
      bind *:8888
      mode http
      default_backend cops

      
backend cops
      mode http
      http-request set-header X-Forwarded-Port %[dst_port]
      balance roundrobin";
   while test $((i++)) -lt $inst; do
      echo "      server server$i  127.0.0.$i:9888"
   done)
      
}

function startCop() {
   local inst=$1
   local start=$SECONDS
   local timeout=8
   local now=0
   local server_addr=127.0.0.$inst
   local server_port=9888

   cd $COP/bin
   inst=0
   $COPEXEC server start -address $server_addr -port $server_port -ca $DST_CERT \
                    -ca-key $DST_KEY -config $RUNCONFIG 2>&1 | sed 's/^/     /' &
   until test "$started" = "$server_addr:$server_port" -o "$now" -gt "$timeout"; do 
      started=$(ss -ltnp src $server_addr:$server_port | awk 'NR!=1 {print $4}')
      sleep .5 
      let now+=1
   done
   printf "COP server on $server_addr:$server_port "
   if test "$started" = "$server_addr:$server_port"; then
      echo "STARTED"
   else 
      RC=$((RC+1))
      echo "FAILED"
   fi
}


function killAllCops() {
   local coppids=$(ps ax | awk '$5~/cop/ {print $1}')
   local proxypids=$(sudo lsof -n -i tcp | awk '$1=="haproxy" && !($2 in a) {a[$2]=$2;print a[$2]}')
   test -n "$coppids" && sudo kill $coppids
   test -n "$proxypids" && sudo kill $proxypids
}


while getopts "\?hPRCBISKXLDd:t:l:n:i:c:k:x:" option; do
  case "$option" in
     d)   DRIVER="$OPTARG" ;;
     n)   COP_INSTANCES="$OPTARG" ;;
     i)   GITID="$OPTARG" ;;
     t)   KEYTYPE=$(tolower $OPTARG);;
     l)   KEYLEN="$OPTARG" ;;
     c)   SRC_CERT="$OPTARG";;
     k)   SRC_KEY="$OPTARG" ;;
     x)   DATADIR="$OPTARG" ;;
     D)   export COP_DEBUG='true' ;;
     P)   PREP="true"  ;;
     R)   RESET="true"  ;;
     C)   CLONE="true" ;;
     B)   BUILD="true" ;;
     I)   INIT="true" ;;
     S)   START="true" ;;
     X)   PROXY="true" ;;
     K)   KILL="true" ;;
     L)   LIST="true" ;;
   \?|h)  usage
          exit 1
          ;;
  esac
done


test -z "$DATADIR" && DATADIR="$HOME/cop"
test -z "$SRC_KEY" && SRC_KEY="$DATADIR/server-key.pem"
test -z "$SRC_CERT" && SRC_CERT="$DATADIR/server-cert.pem"

: ${DRIVER="sqlite3"}
: ${COP_INSTANCES=1}
: ${COP_DEBUG="false"}
: ${GITID="rennman"}
: ${LIST="false"}
: ${PREP="false"}
: ${RESET="false"}
: ${CLONE="false"}
: ${BUILD="false"}
: ${INIT="false"}
: ${START="false"}
: ${PROXY="false"}
: ${KILL="false"}
: ${KEYTYPE="ecdsa"}
: ${KEYLEN="256"}
test $KEYTYPE = "rsa" && SSLKEYCMD=$KEYTYPE || SSLKEYCMD="ec"

case $DRIVER in 
   postgres) DATASRC="dbname=cop host=127.0.0.1 port=$POSTGRES_PORT user=postgres password=postgres sslmode=disable" ;;
   sqlite3)   DATASRC="cop.db" ;;
   mysql)    DATASRC="root:mysql@tcp(localhost:$MYSQL_PORT)/cop?parseTime=true" ;;
esac

$($LIST)  && listCop
$($PREP)  && installPrereq
$($RESET) && resetCop
$($CLONE) && cloneCop
$($BUILD) && buildCop
$($INIT)  && initCop
$($KILL)  && killAllCops
$($PROXY) && startHaproxy $COP_INSTANCES

if $($START); then
   genRunconfig
   inst=0
   while test $((inst++)) -lt $COP_INSTANCES; do
      startCop $inst
   done
fi
exit $RC
