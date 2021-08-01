========================================================================================
### Disclaimer: **In Progress** This is just note keeping. Actual script is network.sh
========================================================================================

=====================================
### Simple Network Setup
=====================================

# Note: 
sudo systemctl stop tor
docker-compose -f docker-compose.yaml down -v
sudo rm -r volumes && mkdir volumes
sudo rm -r organizations && mkdir organizations
sudo rm -r channel-artifacts && mkdir channel-artifacts
sudo rm *.tar.gz

## Commands with Latest Fabric Version
# Generating certificates using cryptogen tool
./bin/cryptogen generate --config=./crypto-config-org1.yaml --output="organizations"

./bin/cryptogen generate --config=./crypto-config-org2.yaml --output="organizations"

./bin/cryptogen generate --config=./crypto-config-orderer.yaml --output="organizations"

# Generating CCP files for Org1 and Org2
./ccp-generate.sh

## Generate Genesis Block
<!-- ./bin/configtxgen -outputBlock ./channel-artifacts/genesis_block.block -profile OrdererGenesis -channelID mychannel -->


## Finally Lets run our Network
# Without Couchdb
docker-compose -f docker-compose.yaml up

# With Couchdb
docker-compose -f docker-compose-test-net.yaml -f docker-compose-couch.yaml up

## Include monitor.sh file to monitor logs from all the containers
./scripts/monitordocker.sh <network_name>
./scripts/monitordocker.sh fabric_test


## Creating Channel
Set Env variables:

export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

./bin/osnadmin channel join --channelID mychannel --config-block ./channel-artifacts/genesis_block.block -o localhost:8443 --ca-file "$ORDERER_CA" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" >&log.txt


## Join Channel 

=================================
## To Resolve ERROR:
Set 
<!-- export FABRIC_CFG_PATH=${PWD}/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID=Org1MSP
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=peer0.org1.example.com:7051
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export BLOCKFILE=$PWD/channel-artifacts/genesis_block.block -->
=================================
export MAX_RETRY=5
export CLI_DELAY=3
export VERBOSE="false"

export CHANNEL_NAME="mychannel"
export FABRIC_CFG_PATH=$PWD/
export BLOCKFILE=$PWD/channel-artifacts/genesis_block.block
==================================

# Peer 1

export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051


peer channel join -b $BLOCKFILE >&log.txt
--------------------------------------------

# Peer 2

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer channel join -b $BLOCKFILE >&log.txt
=================================

### Generating Anchor peer...

# Note:-  Actual Command is 
# peer channel update -o orderer.example.com:7050 --ordererTLSHostnameOverride orderer.example.com # -c $CHANNEL_NAME -f ${CORE_PEER_LOCALMSPID}anchors.tx --tls --cafile "$ORDERER_CA" >&log.txt


## Set Anchor Peer
# Peer 1
ORG=1
CHANNEL_NAME=mychannel
docker exec cli ./scripts/setAnchorPeer.sh $ORG $CHANNEL_NAME

# Peer 2
ORG=2
CHANNEL_NAME=mychannel
docker exec cli ./scripts/setAnchorPeer.sh $ORG $CHANNEL_NAME


=====================================
### Chaincode
=====================================
## 1. Golang
# Initializing Module
go mod init fabcar.go

# Building Chaincode
go build

GO111MODULE=on go mod vendor

---------------------------------------------
### Chaincode Lifecycle
# Note:- 
Set bin path & FABRIC_CFG_PATH

export PATH=${PWD}/../bin:$PATH

export FABRIC_CFG_PATH=$PWD/


## Step one: Package the smart contract
peer lifecycle chaincode package chaincode.tar.gz --path ./chaincode/go/ --lang golang --label chaincode01_1.0

peer lifecycle chaincode package fabcar_1.0.tar.gz --path ./chaincode/go/ --lang golang --label fabcar_1.0

peer lifecycle chaincode package fabcar_1.0.tar.gz --path ./chaincode/go/ --lang node --label fabcar_1.0


## 2. Typescript
peer lifecycle chaincode package basic.tar.gz --path ./chaincode/typescript/ --lang node --label basic_1.0


## Step two: Install the chaincode package

Set env variables to Org 1:

export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install chaincode.tar.gz
---------------------------------------------

Set env variables to Org 2:

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install chaincode.tar.gz

# Querying the Chaincode
peer lifecycle chaincode queryinstalled

export CC_PACKAGE_ID=<package_id>

## Step three: Approve a chaincode definition
# As Org 2
peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# As Org 1
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

## Step four: Committing the chaincode definition to the channel
# Check Commit Readiness
peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name basic --version 1.0 --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --output json

# Step five: Commit Chaincode
peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 1.0 --sequence 1 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt


# Query Committed (Approvals)
peer lifecycle chaincode querycommitted --channelID mychannel --name basic --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem


## Invoking the Chaincode
peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem -C mychannel -n basic --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt -c '{"function":"InitLedger","Args":[]}'

### Commands to invoke | query chaincode
# Query All Cars
peer chaincode query -C mychannel -n basic -c '{"Args":["queryAllCars"]}'

===============================
# Note:- Query works without any other parameters, but invoke needs to provide all parameters
===============================

# Create Car
peer chaincode invoke -C mychannel -n basic -c '{"Args":["createCar", "CAR10", "Pak", "My-Car", "Black", "Subhan"]}' --waitForEvent -o localhost:7050 --peerAddresses=localhost:7051 --peerAddresses=localhost:9051 --tlsRootCertFiles  organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --tlsRootCertFiles  organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --tls --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

# Update Car
peer chaincode invoke -C mychannel -n basic -c '{"Args":["ChangeCarOwner", "CAR10", "Subhan ***"]}' --waitForEvent -o localhost:7050 --peerAddresses=localhost:7051 --peerAddresses=localhost:9051 --tlsRootCertFiles  organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --tlsRootCertFiles  organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --tls --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

## Upgrading the Chaincode
peer lifecycle chaincode package fabcar_2.0.tar.gz --path chaincode/javascript/ --lang node --label fabric_2.0

# Set env as Org 1

export FABRIC_CFG_PATH=$PWD/
export CORE_PEER_TLS_ENABLED=true
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

peer lifecycle chaincode install fabcar_2.0.tar.gz

peer lifecycle chaincode queryinstalled

export NEW_CC_PACKAGE_ID=<package_id>

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 2.0 --package-id $NEW_CC_PACKAGE_ID --sequence 2 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

export CORE_PEER_LOCALMSPID="Org2MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
export CORE_PEER_ADDRESS=localhost:9051

peer lifecycle chaincode install fabcar_2.0.tar.gz

peer lifecycle chaincode checkcommitreadiness --channelID mychannel --name basic --version 2.0 --sequence 2 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --output json

peer lifecycle chaincode approveformyorg -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 2.0 --package-id $NEW_CC_PACKAGE_ID --sequence 2 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --channelID mychannel --name basic --version 2.0 --sequence 2 --tls --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt



# Logging Level
FABRIC_LOGGING_SPEC=info
CORE_CHAINCODE_LOGGING_SHIM=debug
CORE_CHAINCODE_LOGGING_LEVEL=debug# HLF-Advanced-Network-Project
