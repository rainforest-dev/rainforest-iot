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
