FROM postgres:lastest

# Copy the cop executable
COPY cop $GOPATH/bin/

# Copy the configuration files
COPY *.json /config/
COPY *.pem /root/.cop/

WORKDIR $GOPATH/src/github.com/hyperledger/fabric-cop
