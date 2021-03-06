export CORE_PEER_TLS_ENABLED=true
export ORDERER_CA=${PWD}/../../../channel-artifacts/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
export FABRIC_CFG_PATH=${PWD}/../../../

export TLS_FILE=${PWD}/../../../channel-artifacts/ordererOrganizations/example.com/orderers/orderer4.example.com/tls/server.crt

export CHANNEL_NAME=mychannel
export SYSTEM_CHANNEL_NAME=sys-channel

setGlobalsForOrderer() {
    export CORE_PEER_LOCALMSPID="OrdererMSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${PWD}/../../../channel-artifacts/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${PWD}/../../../channel-artifacts/ordererOrganizations/example.com/users/Admin@example.com/msp

}

addEndPointToSystemChannel() {
    setGlobalsForOrderer

    peer channel fetch config config_block.pb -o localhost:7050 -c $SYSTEM_CHANNEL_NAME --tls --cafile $ORDERER_CA

    configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config >config.json
    
    jq ".channel_group.values.OrdererAddresses.value.addresses += [\"orderer4.example.com:10050\"]" config.json >modified_config.json
    
    configtxlator proto_encode --input config.json --type common.Config --output config.pb
    configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb
    
    configtxlator compute_update --channel_id $SYSTEM_CHANNEL_NAME --original config.pb --updated modified_config.pb --output config_update.pb
    configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate --output config_update.json
    
    echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"sys-channel\", \"type\":2}},\"data\":{\"config_update\":"$(cat config_update.json)"}}}" | jq . >config_update_in_envelope.json
    
    configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope --output config_update_in_envelope.pb
    
    peer channel update -f config_update_in_envelope.pb -c $SYSTEM_CHANNEL_NAME -o localhost:7050 --tls true --cafile $ORDERER_CA

}

addEndPointToSystemChannel
