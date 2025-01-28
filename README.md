# Rainforest IoT Platform
## Raspberry Pi 4B
### Setup
#### OS
#### Install Docker
- create remote docker context

#### Setup from client via `terraform`

```bash
docker context create raspberrypi-4 --docker "host=ssh://raspberrypi-4" 
```
```bash
terraform init
terraform apply
```

### Components
1. homeassistant
enables the integration of HACS
```bash
docker exec -it <name of the container running homeassistant> bash
wget -O - https://get.hacs.xyz | bash -
```
2. shairport-sync
3. watchtower
4. openspeedtest