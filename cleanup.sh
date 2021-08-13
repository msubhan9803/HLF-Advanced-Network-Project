sudo systemctl stop tor
docker-compose -f docker-compose.yaml down -v
sudo rm -r channel-artifacts && mkdir channel-artifacts
sudo rm *.tar.gz


cd addOrg3
rm -r crypto-config && mkdir crypto-config
docker-compose -f docker-compose.yaml down -v
cd scripts
rm *.pb
rm *.json
rm *.tx
rm ./channel-artifacts/mychannel.block

cd system-channel/scripts/
rm *.pb
rm *.json
rm *.tx
rm ./channel-artifacts/org1-org3-channel.block

cd ../../../../

cd ./create-certificate-with-ca/
sudo rm -r fabric-ca
docker-compose down -v

cd ../

rm -r addOrderer/scripts/*/*.pb
rm -r addOrderer/scripts/*/*.json
rm -r addOrderer/scripts/*/*.block

docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)

docker volume prune
docker network prune