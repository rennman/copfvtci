FROM hyperledger/fabric-cop

# Copy the configuration for the cop and certificate setups
WORKDIR /etc/hyperledger/fabric-cop/
COPY cop.json /etc/hyperledger/fabric-cop/cop.json
COPY csr.json /etc/hyperledger/fabric-cop/csr.json
COPY cop.json /etc/hyperledger/fabric-cop/cop_client.json

# Copy the same certificates that are currently hardcoded into the peers
COPY ec-key.pem /etc/hyperledger/fabric-cop/ec-key.pem
COPY ec.pem /etc/hyperledger/fabric-cop/ec.pem

COPY wait-for-proxy.sh /etc/hyperledger/fabric-cop/wait-for-proxy.sh
RUN chmod +x /etc/hyperledger/fabric-cop/wait-for-proxy.sh

EXPOSE 8888
