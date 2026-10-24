# Bedroom HomePod: announcements and Bambii's music

The Bedroom HomePod mini (`192.168.0.105`) is driven by Music Assistant (MA) on the Pi, and
Home Assistant (HA) talks to it through MA's `media_player.bedroom_2`. `media_player.bedroom`
is the separate `apple_tv` integration entity and is the one Google Home exposes.

```
HA script → music_assistant integration → MA (localhost:8095) → AirPlay 2 → HomePod mini
```

HA's config lives in the `homeassistant_configuration` volume, edited from the HA UI, so it is
not applied by Terraform. `configs/homeassistant/homepod/` holds the copies of what was added to
`/config/scripts.yaml` and `/config/automations.yaml`; keep them in sync by hand.

## State that is not in any file here

| Where | Setting | Why |
|---|---|---|
| HA `music_assistant` config entry | `url = http://localhost:8095` | It pointed at `https://music-assistant.rainforest.tools`; when the Mac's tunnel went down on 2026-10-17 HA lost MA and every MA player went `unavailable`. HA and MA both use host networking on the Pi, so loopback needs no tunnel. The integration has no reconfigure flow: stop HA, edit `.storage/core.config_entries`, start HA. |
| MA player `Bedroom` | AirPlay protocol: Prefer AirPlay 2 | On automatic (RAOP) the HomePod accepts the connection and never starts playback; MA fails with `Playback failed to start` after 10 s. |
| MA plugin `Spotify Connect` | player `Bedroom`, name `臥室 HomePod`, player switching off | Shows the HomePod as a Spotify Connect device to any phone on the LAN. |
| MA provider `Spotify` | logged in | Needed for `script.bambii_music_on`. Re-login in MA → Settings → Providers → Spotify when it logs `Error loading provider ... 'refresh_token'`. |

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
