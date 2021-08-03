removeOldArtifacts() {
    sudo systemctl stop tor
    docker-compose -f docker-compose.yaml down -v
    sudo rm -r volumes && mkdir volumes
    sudo rm -r organizations && mkdir organizations
    sudo rm -r channel-artifacts && mkdir channel-artifacts
    sudo rm *.tar.gz
    # chmod -R 0755 .
}

generateCryptoMaterial() {
    ./bin/cryptogen generate --config=./crypto-config-org1.yaml --output="organizations"
    ./bin/cryptogen generate --config=./crypto-config-org2.yaml --output="organizations"
    ./bin/cryptogen generate --config=./crypto-config-orderer.yaml --output="organizations"
}

generateChannelArtifacts() {
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
    docker-compose up -d
}

createChannel() {
    export CORE_PEER_TLS_ENABLED=true
    export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export FABRIC_CFG_PATH=${PWD}/

    export CHANNEL_NAME=mychannel
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:7051

    peer channel create -o localhost:7050 -c $CHANNEL_NAME \
        --ordererTLSHostnameOverride orderer.example.com \
        -f ./channel-artifacts/${CHANNEL_NAME}.tx --outputBlock ./channel-artifacts/genesis_block.block \
        --tls $CORE_PEER_TLS_ENABLED --cafile $ORDERER_CA
}

presetUp() {
    export MAX_RETRY=5
    export CLI_DELAY=3
    export VERBOSE="false"=
    export CHANNEL_NAME="mychannel"
    export FABRIC_CFG_PATH=$PWD/
    export BLOCKFILE=$PWD/channel-artifacts/genesis_block.block
    export ORDERER_CA=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export ORDERER_ADMIN_TLS_SIGN_CERT=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.crt
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/server.key
}

joinChannelAsPeer0Org1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export PEER0_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG1_CA
    export CORE_PEER_ADDRESS=localhost:7051
    peer channel join -b $BLOCKFILE
}

joinChannelAsPeer1Org1() {
    export PEER1_ORG1_CA=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER1_ORG1_CA
    export CORE_PEER_ADDRESS=localhost:8051
    peer channel join -b $BLOCKFILE
}

joinChannelAsPeer0Org2() {
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export PEER0_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER0_ORG2_CA
    export CORE_PEER_ADDRESS=localhost:9051
    peer channel join -b $BLOCKFILE
}

joinChannelAsPeer1Org2() {
    export PEER1_ORG2_CA=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt
    export CORE_PEER_TLS_ROOTCERT_FILE=$PEER1_ORG2_CA
    export CORE_PEER_ADDRESS=localhost:10051
    peer channel join -b $BLOCKFILE
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
}

packageChaincode() {
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
}

installChaincodeOnPeer1Org1() {
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_ADDRESS=localhost:8051
    peer lifecycle chaincode install fabcar_1.0.tar.gz
}

installChaincodeOnPeer0Org2() {
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID="Org2MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:9051

    peer lifecycle chaincode install fabcar_1.0.tar.gz
}

installChaincodeOnPeer1Org2() {
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org2.example.com/users/Admin@org2.example.com/msp
    export CORE_PEER_ADDRESS=localhost:10051

    peer lifecycle chaincode install fabcar_1.0.tar.gz
}

queryInstalled() {
    peer lifecycle chaincode queryinstalled >&log.txt
    cat log.txt
    PACKAGE_ID=$(sed -n "/${CC_NAME}_${VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)
    export CC_PACKAGE_ID=PACKAGE_ID
    echo PackageID is ${CC_PACKAGE_ID}
    echo "===================== Query installed successful on peer0.org1 on channel ===================== "
}

approveChaincodeForOrg2() {
    peer lifecycle chaincode approveformyorg -o localhost:7050 \ 
    --ordererTLSHostnameOverride orderer.example.com --channelID mychannel \ 
    --name basic --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls \ 
    --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

approveChaincodeForOrg1() {
    export CORE_PEER_LOCALMSPID="Org1MSP"
    export CORE_PEER_MSPCONFIGPATH=${PWD}/organizations/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt
    export CORE_PEER_ADDRESS=localhost:7051

    peer lifecycle chaincode approveformyorg -o localhost:7050 \ 
    --ordererTLSHostnameOverride orderer.example.com --channelID mychannel \ 
    --name basic --version 1.0 --package-id $CC_PACKAGE_ID --sequence 1 --tls \ 
    --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

checkCommitReadiness() {
    peer lifecycle chaincode checkcommitreadiness --channelID mychannel \ 
    --name basic --version 1.0 --sequence 1 --tls \ 
    --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem --output json
}

commitChaincode() {
    peer lifecycle chaincode commit -o localhost:7050 --ordererTLSHostnameOverride orderer.example.com \ 
    --channelID mychannel --name basic --version 1.0 --sequence 1 --tls \ 
    --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \ 
    --peerAddresses localhost:7051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \ 
    --peerAddresses localhost:9051 --tlsRootCertFiles ${PWD}/organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt
}

queryCommitted() {
    peer lifecycle chaincode querycommitted --channelID mychannel --name basic \ 
    --cafile ${PWD}/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

invodeChaincode() {
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
    peer chaincode query -C mychannel -n basic -c '{"Args":["queryAllCars"]}'
}

createCar() {
    peer chaincode invoke -C mychannel -n basic -c '{"Args":["createCar", "CAR10", "Pak", "My-Car", "Black", "Subhan"]}' \ 
    --waitForEvent -o localhost:7050 --peerAddresses=localhost:7051 --peerAddresses=localhost:9051 \ 
    --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \ 
    --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --tls \ 
    --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

updateCar() {
    peer chaincode invoke -C mychannel -n basic -c '{"Args":["ChangeCarOwner", "CAR10", "Subhan ***"]}' \ 
    --waitForEvent -o localhost:7050 --peerAddresses=localhost:7051 --peerAddresses=localhost:9051 \ 
    --tlsRootCertFiles organizations/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \ 
    --tlsRootCertFiles organizations/peerOrganizations/org2.example.com/peers/peer0.org2.example.com/tls/ca.crt --tls \ 
    --cafile organizations/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
}

removeOldArtifacts
# generateCryptoMaterial
# generateChannelArtifacts
# runNetwork
# createChannel
# presetUp
# joinChannelAsPeer0Org1
# joinChannelAsPeer1Org1
# joinChannelAsPeer0Org2
# joinChannelAsPeer1Org2
# updateAnchorPeerOrg1
# updateAnchorPeerOrg2
# packageChaincode
# installChaincodeOnPeer0Org1
# installChaincodeOnPeer1Org1
# installChaincodeOnPeer0Org2
# installChaincodeOnPeer1Org2
# queryInstalled
# approveChaincodeForOrg2
# approveChaincodeForOrg1
# checkCommitReadiness
# commitChaincode
# queryCommitted
# invodeChaincode
# queryAllCars
# createCar
# updateCar
