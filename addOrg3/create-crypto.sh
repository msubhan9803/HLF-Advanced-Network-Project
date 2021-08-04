
chmod -R 0755 ./crypto-config
# Delete existing artifacts
sudo rm -r crypto-config && mkdir crypto-config

#Generate Crypto artifactes for organizations
cryptogen generate --config=./org3-crypto.yaml --output=./crypto-config/
