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
rm ./channel-artifacts/mychannel.block

cd ../../