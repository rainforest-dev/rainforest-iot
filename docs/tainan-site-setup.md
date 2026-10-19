# Tainan site monitoring — setup

The Tainan home is a second site: a Synology DS725+ (`rainforest-nas`, tailnet `100.84.80.123`), a
UniFi Cloud Gateway Ultra (HiNet 500/500), a USW Flex XG and two Zyxel Nebula APs (NWA130BE,
NWA50AX PRO).

The UCG Ultra has three networks:

| Network | VLAN | Subnet | On it |
|---|---|---|---|
| Default | 1 | `192.168.0.0/24` | UCG `.1`, USW Flex XG `.196`, NWA130BE `.173`, NWA50AX PRO `.54` |
| Work | 10 | `192.168.10.0/24` | NAS `.249` |
| IoT | 107 | `192.168.107.0/24` | smart plugs, a Raspberry Pi 4 |

The Pi cannot open connections into Tainan: the Default network is `192.168.0.0/24` like the Taipei LAN,
so a subnet route would collide, and the tailnet ACL does not let the tagged Pi dial the NAS. The NAS
therefore collects and pushes. Alloy on the NAS reaches the Default network through the UCG, so the
UniFi firewall must allow Work → Default for ICMP and UDP 161.

```mermaid
flowchart LR
  subgraph TN["Tainan LAN"]
    UCG[UCG Ultra] --- SW[USW Flex XG]
    AP1[NWA130BE]
    AP2[NWA50AX PRO]
    subgraph NAS["DS725+ Container Manager"]
      UP[unpoller] --> AL[Grafana Alloy]
      ST[speedtest-exporter] --> AL
    end
    UCG -->|UniFi API| UP
    AL -->|SNMP| AP1
    AL -->|ICMP| AP2
    AL -->|SNMP| NAS
  end
  AL -->|remote_write over tailnet, site=tainan| PROM[Pi Prometheus :30090]
  PROM --> AM[Alertmanager → phone]
  TSH[Mac: tsh + Terraform] -->|Teleport, agentless OpenSSH| NAS
```

Terraform for the site lives in `sites/tainan` with its own state, so an expired Teleport certificate can
never break `terraform plan` for the Pi. Alert rules live in the main root
(`modules/prometheus-stack`, group `remote-sites`).

## 1. DSM (Control Panel)

- **Terminal & SNMP → Terminal**: enable SSH on port 22.
- **Terminal & SNMP → SNMP**: untick SNMPv1/v2c. Tick SNMPv3 with user `alloy`, protocol SHA, privacy
  on with AES, and the two passwords from `sites/tainan/terraform.tfvars`.
- **Security → Firewall**: enable, and in the profile add, in this order:
  1. Allow TCP 22 from `100.86.67.66` (the Mac running the Teleport proxy).
  2. Deny TCP 22 from all.
  3. Allow UDP 161 from `172.16.0.0/12` (the Alloy container on a Docker bridge).
  4. Deny UDP 161 from all.

  Leave "if no rules are matched" on **Allow**, so DSM, SMB and the nightly rsync keep working.

## 2. Join the NAS to Teleport (agentless OpenSSH)

On the Mac, create a one-hour join token:

```bash
kubectl -n homelab exec deploy/homelab-teleport-auth -c teleport -- tctl tokens add --type=node --ttl=1h
```

On DSM, **Task Scheduler → Create → Scheduled Task → User-defined script**, user `root`, run once, with:

```bash
set -e
cd /tmp
curl -fsSL https://cdn.teleport.dev/teleport-v15.5.4-linux-amd64-bin.tar.gz | tar xz
/tmp/teleport/teleport join openssh \
  --proxy-server=tp.rainforest.tools:443 \
  --join-method=token --token=<TOKEN> \
  --address=100.84.80.123:22 \
  --labels=site=tainan,role=nas \
  --openssh-config=/etc/ssh/sshd_config
```

Then turn SSH off and on again in DSM so sshd reloads the Teleport CA. Confirm the node with
`tctl nodes ls`.

**DSM upgrades can rewrite `/etc/ssh/sshd_config`** and drop the `TrustedUserCAKeys` and
`HostCertificate` lines the join added. If SSH through Teleport stops working after an update, run the
task again with a fresh token.

## 3. Let the Teleport login run docker

Teleport logs in as `rainforest` (the only login in the `access` role). DSM lets only root use the
Docker socket, so add a **Triggered Task → Boot-up**, user `root`:

```bash
synogroup --get docker >/dev/null 2>&1 || synogroup --add docker
synogroup --get docker | grep -q '\[rainforest\]' || synogroup --memberadd docker rainforest
chown root:docker /var/run/docker.sock
```

Run it once by hand after creating it.

## 4. UniFi read access (UCG Ultra)

Pick one:

- **View Only local admin** (least privilege): UniFi OS → Admins & Users → Add Admin, restrict to
  local access, role View Only. Put it in `unifi_user` / `unifi_pass`.
- **API key**: UniFi Network → Settings → Control Plane → Integrations → Create API Key. Put it in
  `unifi_api_key`. The key is not scoped to read-only.

## 5. Nebula SNMP

Nebula site `rainforest-network` → Site settings → Management access: tick **SNMP** and set the SNMPv2
community to `ap_snmp_community` from `terraform.tfvars`. If Nebula's SNMPv3 option takes the same
`alloy` user with SHA and AES, use that instead and set `ap_snmp_auth = "v3"`. Only the NWA130BE
answers; the NWA50AX PRO has no SNMP and is pinged instead.

## 6. Deploy

```bash
tsh login --proxy=tp.rainforest.tools:443 --user=rainforest
tsh config --proxy=tp.rainforest.tools >> ~/.ssh/config
ssh rainforest@rainforest-nas.tp.rainforest.tools docker ps   # must list containers

cd sites/tainan
cp terraform.tfvars.example terraform.tfvars   # fill it in
terraform init
terraform plan
terraform apply
```

## 7. Verify

On the Pi Prometheus (`http://100.81.160.108:30090`):

- `up{site="tainan"}`: every job is 1 (`isp_icmp`, `lan_icmp`, `snmp`, `unpoller`, `speedtest`).
- `raidStatus{site="tainan"}` and `diskTemperature{site="tainan"}` return the NAS volumes and disks.
- `probe_success{site="tainan", job="isp_icmp"}` is 1 for all three ISP targets.

The `speedtest` job runs once an hour. Each run moves about 1 GB at 500 Mbps.
