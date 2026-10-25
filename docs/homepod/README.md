# Bedroom HomePod: announcements and Bambii's music

The Bedroom HomePod mini (`192.168.0.105`) is driven by Music Assistant (MA) on the Pi, and
Home Assistant (HA) talks to it through MA's `media_player.bedroom_2`. `media_player.bedroom`
is the separate `apple_tv` integration entity and is the one Google Home exposes.

```
HA script → music_assistant integration → MA (localhost:8095) → AirPlay 2 → HomePod mini
```

HA's config lives in the `homeassistant_configuration` volume, edited from the HA UI, so it is
not applied by Terraform. The YAML files next to this README are copies of what was added to
`/config/scripts.yaml` and `/config/automations.yaml`; keep them in sync by hand.

## State that is not in any file here

| Where | Setting | Why |
|---|---|---|
| HA `music_assistant` config entry | `url = http://localhost:8095` | It pointed at `https://music-assistant.rainforest.tools`; when the Mac's tunnel went down on 2026-10-17 HA lost MA and every MA player went `unavailable`. HA and MA both use host networking on the Pi, so loopback needs no tunnel. The integration has no reconfigure flow: stop HA, edit `.storage/core.config_entries`, start HA. |
| MA image | `2.10.8` (was 2.7.11) | 2.7's librespot cannot fetch Spotify audio since 2026-08-10. Rollback: image `ghcr.io/music-assistant/server:2.7.11-rollback` and `~/backups/music_assistant_data-20261025-2.7.11.tgz` on the Pi. |
| MA player `Bedroom` | streaming mode `auto` (AirPlay 2, PTP) | The HomePod mini plays only over AirPlay 2 with PTP; RAOP and `ap2_compat` never connect. PTP needs UDP 319/320 open from the LAN. |
| MA plugin `Spotify Connect` | backend Spotify Soloist, player `Bedroom` | Shows the HomePod as `Bedroom \| Music Assistant` in Spotify apps on the LAN. go-librespot connects but this account gets no audio on it. |
| MA provider `Spotify` | playback backend Spotify Soloist | Needed for `script.bambii_music_on`. librespot fails every track with `error audio key 0 1` on this account. Soloist needs a Premium API key from developer.spotify.com/dashboard/soloist and one pairing from a Spotify app on the LAN. |
| HA image | `2026.10.4` (was 2026.3.3) | Waze needs pywaze ≥ 1.2.4; 2026.3.3 ships 1.1.1, which Waze answers with 403 since 2026-10. |
| HA HomeKit bridge | `input_boolean.bambii_music` added to `include_entities` | Apple Home shows it as a switch; a Home scene or Siri turns it on, which runs `script.bambii_music_on`. |
| HA Waze Travel Time | `Home → 台北車站`, origin `zone.home`, region `eu` | Placeholder entry; it exists so `waze_travel_time.get_travel_times` is registered. That action takes free-text destinations such as a calendar event's location. |
| UFW on the Pi | LAN → tcp `32768:60999`, udp `319:320` | Spotify Connect and Soloist pairing bind their getInfo endpoint to a random ephemeral port; with it blocked, Spotify apps see the mDNS record and hide the device. In `ansible/playbooks/system-hardening.yml`. |

## Entities

- `script.homepod_announce(message, volume=40)`: Google Translate TTS in `zh-TW`, played with
  MA's announce. MA sets the volume for the announcement, then restores the volume and whatever
  was playing.
- `script.bambii_music_on(playlist, volume=0.25)` / `script.bambii_music_off`: play or stop a
  Spotify playlist through MA. `input_boolean.bambii_music` (exposed to Google Home as
  "Bambii Music") calls them. Its triggers need `from:` so restoring the switch after an HA
  restart does not start music.
- `automation.homepod_ti_xing_fan_ben`: disabled reminder template.
- `automation.ban_ban_yin_le_mei_ri_pai_cheng`: disabled daily schedule for Bambii's music.

## Test

```bash
curl -X POST -H "Authorization: Bearer $HA_TOKEN" -H 'Content-Type: application/json' \
  -d '{"message":"測試","volume":25}' http://192.168.0.128:8123/api/services/script/homepod_announce
docker exec music-assistant grep -E 'Announcement to player Bedroom' /data/musicassistant.log | tail -3
```

A working run logs `playing the announcement` and then `restore previous state`.

## Upgrading or rolling back HA and MA

Both run the `stable` tag through Terraform (`modules/homeassistant`, `modules/music-assistant`),
so an upgrade is: `docker pull` the version tag on the Pi (30+ minutes on the SD card), tag the
running image as `<version>-rollback`, back up the volume, retag `stable`, then
`terraform apply -target=module.<name>`. The `null_resource` provisioners re-run against the new
container and are idempotent.

Backups taken on 2026-10-25, in `~/backups/` on the Pi:

| Service | Image tag to roll back to | Volume backup |
|---|---|---|
| Music Assistant | `ghcr.io/music-assistant/server:2.7.11-rollback` | `music_assistant_data-20261025-2.7.11.tgz` |
| Home Assistant | `ghcr.io/home-assistant/home-assistant:2026.3.3-rollback` | `homeassistant_configuration-20261025-2026.3.3.tgz` |

Roll back: stop the container, restore the volume
(`docker run --rm -v <volume>:/c -v ~/backups:/b alpine sh -c 'rm -rf /c/* /c/.[!.]* && tar xzf /b/<file> -C /c'`),
`docker tag <rollback tag> <image>:stable`, then `terraform apply -target=module.<name>`.
