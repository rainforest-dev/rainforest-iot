# Tainan Raspberry Pi 4: adoption and upgrade plan

The Pi 4 at the Tainan site is managed by hand. `sites/tainan-rpi4` brings its running containers into
Terraform without changing them, and the upgrades follow as separate commits. Access and routing are in
`docs/tainan-site-setup.md`, section 8.

## Current state

Inventory taken on 2026-11-01, read-only.

| Item | State |
|---|---|
| Hardware | Raspberry Pi 4 Model B, 8 GB, 59 GB SD card (63% used) |
| OS | Debian 12, kernel 6.6.62, 476 days of uptime, 420 apt upgrades pending |
| Docker | 27.5.1, Compose 2.32.4 |
| `homeassistant` | Container install, 2025.1.4, host network, privileged, volume `homeassistant_configuration` |
| `acton-3` | shairport-sync AirPlay receiver for the Acton III speaker on the headphone jack, image from January 2025 |
| `openspeedtest` | Ports 3000 and 3001, image from January 2024 |
| Stopped | `homepage`, `helper`, `add-configuration` and two devcontainers, not adopted |

Home Assistant has 459 MB of config, a 14 MB recorder database, 15 devices and 75 entities.
`automations.yaml` and `scripts.yaml` are empty, and `configuration.yaml` has 11 lines. Its custom
integrations are HACS 2.0.4, `dyson_local` 1.4.2 and `panasonic_smart_app` 2.8.4. The log has about
10,000 recorder task errors; read those before the upgrade, because a damaged database changes the plan.

The containers run images by ID and most tags have since moved, so `main.tf` pins those IDs.

CPU was idle when sampled: load 0.18, each container under 2%. Fleet showed 38% earlier, which this sample
does not explain.

## Adoption

Run this from a checkout of `main` that has this root. State stays local and gitignored.

```bash
cd sites/tainan-rpi4
terraform init
terraform plan    # must say: 5 to import, 0 to add, 0 to change, 0 to destroy
terraform apply
```

Delete `imports.tf` afterwards. Stop if the plan shows anything other than imports. Each container has
`ignore_changes = all` because an import leaves env, volumes and provider defaults unset, which would
otherwise force a replacement. The commit that upgrades a container removes that block.

## Backup

The steps below do not stop any service. Copying a live SQLite file can give a corrupt copy, so take the
recorder database with SQLite's backup API and leave the live files out of the archive.

```bash
ssh rpi4-tainan "docker exec homeassistant python3 -c \"import sqlite3; s=sqlite3.connect('/config/home-assistant_v2.db'); d=sqlite3.connect('/config/recorder-backup.db'); s.backup(d); d.close()\""

for v in homeassistant_configuration shairport_sync_configuration; do
  ssh rpi4-tainan "sudo tar czf - --exclude='home-assistant_v2.db*' -C /var/lib/docker/volumes/$v/_data ." \
    | ssh <nas>.<teleport-proxy> "cat > <nas-backup-dir>/$v-$(date +%Y%m%d).tar.gz"
done
```

The archive holds `secrets.yaml` and tokens under `.storage`, so keep it readable by the owner only.
Check `tar tzf` on the NAS and delete `recorder-backup.db` from the Pi afterwards.

## Upgrade order

| Step | Change | Downtime | Rollback |
|---|---|---|---|
| 1 | Back up to the NAS | None | None needed |
| 2 | Import into Terraform | None | Delete the state |
| 3 | Reboot on the current OS | 2 to 3 minutes | Someone on site |
| 4 | `apt full-upgrade`, reboot | About 5 minutes | Someone on site; no package rollback |
| 5 | Home Assistant 2026.10.4, pinned tag | About 5 minutes | Old image and the backup |
| 6 | HACS and the two custom integrations | One HA restart | Restore `custom_components` |
| 7 | shairport-sync and OpenSpeedTest, pinned | Under a minute each | Old image ID |
| 8 | Remove stopped containers and unused images | None | Pull again |

Total downtime is about 15 minutes, spread across steps. Do steps 3 and 4 when someone can reach the Pi
that day. Pull new images before stopping a container: a 2 GB pull over Wi-Fi takes a while and should
not count as downtime.

## Risks

The reboot is the largest one. The routing has never been through a boot, and the rule that keeps the Pi
reachable is in NetworkManager plus `/etc/sysctl.d`. If it fails, the Pi can still answer on the IoT subnet
but the relay through the NAS cannot reach it, and the only fix is someone on site. Step 3 runs ahead of
the package upgrade so that a failure has one possible cause. Eth0 comes back on boot unless its
autoconnect is off.

`apt full-upgrade` covers 420 packages, including the kernel, systemd, NetworkManager, OpenSSH and Docker.
The Docker upgrade restarts all three containers. Stay on Debian 12: moving to Debian 13 is a separate
decision.

Home Assistant jumps 21 monthly releases. It can go straight to the target because there is no YAML
config to migrate. The release notes from 2025.2 to 2026.10 have these changes that apply here:

- 2025.5: HomeKit child accessories take their names from Home Assistant.
- 2025.8: Apple TV reports `off` where it reported `standby`.
- 2026.3: images use `zstd`, which needs Docker 23 or later. The Pi has 27.5.1.
- 2026.6: Bluetooth scanning defaults to Auto.

The template and script changes in those notes do not apply, because this install has no templates or
scripts in YAML. UI-created helpers were not checked.

The recorder schema migration is one way, so rollback means the old image plus the restored database. The
14 MB database should migrate quickly.

Of the custom integrations, `panasonic_smart_app` released v2.14.0 in July 2026 and is active. `dyson_local`
last released v1.5.7 in July 2025 and last changed in August 2025, so nothing shows it works on
2026.10. If it fails, the Dyson devices drop out until it is replaced; the rest of Home Assistant keeps
running.

`homeassistant` stays privileged during adoption and the upgrade. That goes against the repo's no-privileged
rule, and dropping it should be a separate change so that a Bluetooth or D-Bus failure is not confused with
the version jump.
