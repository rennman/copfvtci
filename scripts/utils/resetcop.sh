#!/bin/bash
num=$1
: ${num:=1}
COP="$GOPATH/src/github.com/hyperledger/fabric-cop"
SCRIPTDIR="$COP/scripts"
$SCRIPTDIR/cop_setup.sh -R
$SCRIPTDIR/cop_setup.sh -I -X -S -n $num
