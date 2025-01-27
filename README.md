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
2. shairport-sync
3. watchtower
4. openspeedtest