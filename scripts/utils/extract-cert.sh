#!/bin/sh
CLIENTAUTH=$1

test -z $CLIENTAUTH && CLIENTAUTH="$HOME/.cop/client.json"

key=$(cat  $CLIENTAUTH |jq '.publicSigner.key'  |sed 's/"//g')
cert=$(cat $CLIENTAUTH |jq '.publicSigner.cert' |sed 's/"//g')
echo CERT:
echo $cert |base64 -d| openssl x509 -text 2>&1 | sed 's/^/    /'
type=$(echo $key  |base64 -d | head -n1 | awk '{print tolower($2)}')
echo KEY:
echo $key  |base64 -d| openssl $type -text 2>/dev/null| sed 's/^/    /'

#case $1 in
#   d) base64 -d ;;
#   *) awk -v FS='' '
#         BEGIN { printf "-----BEGIN CERTIFICATE-----\n"}
#         { for (i=1; i<=NF; i++) if (i%64) printf $i; else print $i }
#         END   { if ((i%64)!=0) print "" ; printf "-----END CERTIFICATE-----\n" }'
#      ;;
#esac
