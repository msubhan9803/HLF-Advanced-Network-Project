export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
export FABRIC_CFG_PATH=${PWD}/
export MAX_RETRY=5
export CLI_DELAY=3
export VERBOSE="false"=
export CHANNEL_NAME="mychannel"
export FABRIC_CFG_PATH=$PWD/
export BLOCKFILE=$PWD/channel-artifacts/genesis_block.block
export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key

export CHANNEL_NAME=mychannel
export CORE_PEER_LOCALMSPID="Org1MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
export CORE_PEER_ADDRESS=localhost:7051

removeOldArtifacts() {
    echo "===================== Removing Old Artifacts... ===================== "

    sudo systemctl stop tor
    docker-compose -f docker-compose.yaml down -v
    sudo rm -r volumes && mkdir volumes
    sudo rm -r organizations && mkdir organizations
    sudo rm -r channel-artifacts && mkdir channel-artifacts
    sudo rm *.tar.gz
    # chmod -R 0755 .
}

generateCryptoMaterial() {
    echo "===================== Generating Crypto Materials... ===================== "

    ./bin/cryptogen generate --config=./crypto-config-org1.yaml --output="organizations"
    ./bin/cryptogen generate --config=./crypto-config-org2.yaml --output="organizations"
    ./bin/cryptogen generate --config=./crypto-config-orderer.yaml --output="organizations"
}

generateChannelArtifacts() {
    echo "===================== Generating Channel Artifacts... ===================== "

    SYS_CHANNEL="sys-channel"
    CHANNEL_NAME="mychannel"

    echo $CHANNEL_NAME

    # Generate System Genesis block
    ./bin/configtxgen -profile OrdererGenesis -configPath . -channelID $SYS_CHANNEL -outputBlock ./channel-artifacts/genesis_block.block

    # Generate channel configuration block
    ./bin/configtxgen -profile BasicChannel -configPath . -outputCreateChannelTx ./channel-artifacts/mychannel.tx -channelID $CHANNEL_NAME

    echo "#######    Generating anchor peer update for Org1MSP  ##########"
    ./bin/configtxgen -profile BasicChannel -configPath . -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

    echo "#######    Generating anchor peer update for Org2MSP  ##########"
    ./bin/configtxgen -profile BasicChannel -configPath . -outputAnchorPeersUpdate ./channel-artifacts/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
}

runNetwork() {
    echo "===================== Starting Network... ===================== "

    docker-compose up -d
}

createChannel() {
    echo "===================== Creating Channel... ===================== "

    peer channel create -o localhost:7050 -c $CHANNEL_NAME \
        --ordererTLSHostnameOverride orderer.example.com \
        -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/genesis_block.block \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
}

joinChannelAsPeer0Org1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_ADDRESS=localhost:7051
    peer channel join -b $BLOCKFILE

    echo "===================== Joined Channel as Organization 1 - Peer 0 ===================== "
}

joinChannelAsPeer1Org1() {
    export PEER1_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER1_ORG1_CA
    export CORE_PEER_ADDRESS=localhost:8051
    peer channel join -b $BLOCKFILE

    echo "===================== Joined Channel as Organization 1 - Peer 1 ===================== "
}

joinChannelAsPeer0Org2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_ADDRESS=localhost:9051
    peer channel join -b $BLOCKFILE

    echo "===================== Joined Channel as Organization 2 - Peer 0 ===================== "
}

joinChannelAsPeer1Org2() {
    export PEER1_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER1_ORG2_CA
    export CORE_PEER_ADDRESS=localhost:10051
    peer channel join -b $BLOCKFILE

    echo "===================== Joined Channel as Organization 2 - Peer 2 ===================== "
}

updateAnchorPeerOrg1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer channel update -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA

    echo "===================== Updated Anchor Peer of Organization 1 ===================== "
}

updateAnchorPeerOrg2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
    peer channel update -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com \
        -c $CHANNEL_NAME -f ./channel-artifacts/${CORE_PEER_LOCALMSPID}anchors.tx \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA

    echo "===================== Updated Anchor Peer of Organization 2 ===================== "
}

packageChaincode() {
    echo "===================== Packaging Chaincode.. ===================== "

    export PATH=${PWD}/../bin:$PATH
    export FABRIC_CFG_PATH=$PWD/
    peer lifecycle chaincode package fabcar_1.0.tar.gz --path ./chaincode/go/ --lang golang --label fabcar_1.0
}

installChaincodeOnPeer0Org1() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer lifecycle chaincode install fabcar_1.0.tar.gz

    echo "===================== Chaincode installed on Peer 0 of Organization 1 ===================== "
}

installChaincodeOnPeer1Org1() {
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:8051
    peer lifecycle chaincode install fabcar_1.0.tar.gz

    echo "===================== Chaincode installed on Peer 1 of Organization 1 ===================== "
}

installChaincodeOnPeer0Org2() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

    peer lifecycle chaincode install fabcar_1.0.tar.gz

    echo "===================== Chaincode installed on Peer 0 of Organization 2 ===================== "
}

installChaincodeOnPeer1Org2() {
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:10051

    peer lifecycle chaincode install fabcar_1.0.tar.gz

    echo "===================== Chaincode installed on Peer 1 of Organization 2 ===================== "
}

queryInstalled() {
    peer lifecycle chaincode queryinstalled >&log.txt
    cat log.txt
    PACKAGE_ID=$(sed -n "/${CC_NAME}_${VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
    echo PackageID is ${PACKAGE_ID}
}

approveChaincodeForOrg2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    # export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA

    peer lifecycle chaincode approveformyorg -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com --channelID mychannel \
        --name basic --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls \
        --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

    echo "===================== Chaincode Approved for Organization 2 ===================== "
}

approveChaincodeForOrg1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_ADDRESS=localhost:7051

    peer lifecycle chaincode approveformyorg -o localhost:7050 \
        --ordererTLSHostnameOverride orderer.example.com --channelID mychannel \
        --name basic --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls \
        --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

    echo "===================== Chaincode Approved for Organization 1 ===================== "
}

checkCommitReadiness() {
    echo "===================== Checking Commit Readiness... ===================== "

    peer lifecycle chaincode checkcommitreadiness --channelID mychannel \
        --name basic --version 1.0 --sequence 1 --tls \
        --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --output json
}

commitChaincode() {
    echo "===================== Committing Chaincode... ===================== "

    peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \
        --channelID mychannel --name basic --version 1.0 --sequence 1 --tls \
        --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
}

queryCommitted() {
    echo "===================== Querying Committed... ===================== "

    peer lifecycle chaincode querycommitted --channelID mychannel --name basic \
        --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

invodeChaincode() {
    echo "===================== Invoking Chaincode... ===================== "

    peer chaincode invoke -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com --tls \
        --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
        -C mychannel -n basic --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt \
        -c '{"function":"InitLedger","Args":[]}'
}

# ===============================
# Note:- Query works without any other parameters, but invoke needs to provide all parameters
# ===============================

queryAllCars() {
    echo "===================== Querying All Cars... ===================== "

    peer chaincode query -C mychannel -n basic -c '{"Args":["queryAllCars"]}'
}

createCar() {
    echo "===================== Invoking Create Car... ===================== "

    peer chaincode invoke -C mychannel -n basic -c '{"Args":["createCar", "CAR10", "Pak", "My-Car", "Black", "Subhan"]}' \
        --waitForEvent -o localhost:7050 --peerAddresses=localhost:7051 --peerAddresses=localhost:9051 \
        --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --tls \
        --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

updateCar() {
    echo "===================== Invoking Update Car... ===================== "

    peer chaincode invoke -C mychannel -n basic -c '{"Args":["ChangeCarOwner", "CAR10", "Subhan ***"]}' \
        --waitForEvent -o localhost:7050 --peerAddresses=localhost:7051 --peerAddresses=localhost:9051 \
        --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
        --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --tls \
        --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

removeOldArtifacts
generateCryptoMaterial
generateChannelArtifacts
runNetwork
createChannel

sleep 5

joinChannelAsPeer0Org1
joinChannelAsPeer1Org1
joinChannelAsPeer0Org2
joinChannelAsPeer1Org2
updateAnchorPeerOrg1
updateAnchorPeerOrg2
packageChaincode
installChaincodeOnPeer0Org1
installChaincodeOnPeer1Org1
installChaincodeOnPeer0Org2
installChaincodeOnPeer1Org2
queryInstalled

sleep 5

approveChaincodeForOrg2
approveChaincodeForOrg1
checkCommitReadiness
commitChaincode
queryCommitted
invodeChaincode

sleep 5

queryAllCars
createCar
updateCar

sleep 5

queryAllCars
