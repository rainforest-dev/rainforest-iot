# Tainan bedroom: humidity, closet mould and the AC

The bedroom closet at the Tainan house has mould. There is no dehumidifier
in that room, so the Panasonic AC (`climate.leng_qi_ji`, CS-QX50FA2, `panasonic_smart_app`)
does the drying, driven by the Dyson HP09's humidity sensor.

```
room > 70% for 1 h → AC dry mode 2 °C under the room (min 22 °C) → ≥ 1 h and < 55%, or 3 h → AC off → 乾燥防霉 dries the coil
at most 2 runs a day, 6 h apart
```

HA's config lives in the `homeassistant_configuration` volume on the Pi 4, edited by hand, so
Terraform does not apply the YAML here. Keep these copies in sync with `/config` by hand.

## What the room has

| Entity | Notes |
|---|---|
| `sensor.dyson_hp09_humidity`, `_temperature` | The only humidity sensor in the room. `state_class: measurement`, so HA keeps hourly long-term statistics indefinitely. |
| `climate.leng_qi_ji` | Modes `cool, dry, fan_only, auto, heat, off`. Reports indoor temperature, no humidity, no target humidity: dry mode only takes a temperature. |
| `switch.leng_qi_ji_gan_zao_fang_mei` (乾燥防霉) | Command `0x17`, a flag stored in the AC: once on, every power-off runs the fan to dry the coil. The integration marks it `unavailable` whenever the AC is off, which is normal. |
| `sensor.dehumidifier_humidity`, `humidifier.bedroom_dehumidifier` | The LG dehumidifier on the ThinQ account. It is at another house, not here; left out of the automations and of Prometheus. |

The Tainan HomePod minis (`Study`, `Study (2)`) are in the study, and HA cannot read their
temperature or humidity sensors anyway.

## Automations (`automations.yaml`)

They read `sensor.bedroom_humidity`, the highest humidity among the room's sensors that are
online (only the Dyson today; add a closet sensor to its two lists), and
`sensor.bedroom_temperature` (Dyson, else the AC's indoor reading). Alerts go to
`notify.mobile_app_YOUR_PHONE`.

- `closet_dehumidify_start`: `binary_sensor.bedroom_humid` on (room above 70% for an hour,
  re-checked every 30 minutes), room above 20 °C, AC off, no fault, fewer than 2 runs today
  (`counter.closet_dehumidify_runs_today`) and at least 6 h since the last run. Records the
  starting humidity, sets dry mode 2 °C under the room temperature (at least 22 °C; at the room's own temperature the
  compressor idles and humidity climbs back), and turns 乾燥防霉 on while the AC is on.
  Until 2026-11-28 it started at 65% after 15 minutes with an hour's rest: each run dried the
  air in 10 minutes and the room was back at 65% two hours later, so the AC cycled all night.
  Mould needs surfaces damp for long stretches, and an AC uses the most power just after it
  starts, so fewer, longer runs are better.
- `closet_dehumidify_fallback`: no room humidity for 2 h (Dyson unplugged) and outdoor humidity
  above 80% (`weather.forecast_home`): one dry run at 14:00, recorded with start humidity 0.
- `closet_dehumidify_stop`: below 55% for 10 minutes once the run has lasted an hour (so the
  walls and clothes dry, not just the air), 2 h for a fallback run, or 3 h; re-checked
  every 10 minutes so a restart mid-run cannot leave the AC on. Turns the AC off only if it is
  still in dry mode, and alerts when a normal run hits 3 h above 55%.
- `closet_dehumidify_no_progress`: an hour in, humidity has not dropped 5 points from the start.
  Turns the AC off, sets `input_boolean.closet_dehumidify_fault` (衣櫥除濕故障), and alerts.
  No run starts while the fault is on; turn it off in HA after checking the room.
- `closet_dehumidify_fault_reset`: clears a fault left on for 24 h.
- `closet_dehumidify_sensor_offline`: alerts when the room has had no humidity reading for 2 h.
- `closet_dehumidify_daily_reset`: zeroes the runs-today counter at midnight. Fallback runs
  count too.
- `closet_dehumidify_handover`: if anyone switches the AC out of dry mode, the automation lets
  go and will not turn it off later.

`input_boolean.closet_dehumidify` (衣櫥除濕中) marks a run the automation started, so it never
switches off an AC someone turned on themselves.

Dry mode works less well in winter, when the room is cool. If a closet sensor shows the inside
staying above 70% after the room is down to 55%, the closet needs airflow (door ajar, back panel
off the wall, desiccant) before a dehumidifier is worth buying.

## History in Grafana

HA's `prometheus` integration exports only the entities listed by name in `configuration-snippet.yaml`; add a closet sensor there when there is one. The
NAS Alloy scrapes `/api/prometheus` as `job="homeassistant"` and remote-writes it to the Pi 5
with `site="tainan"`. Metric names start with `hass_`, for example:

```promql
hass_sensor_humidity_percent{site="tainan", entity="sensor.dyson_hp09_humidity"}
hass_sensor_temperature_celsius{site="tainan"}
hass_climate_action{site="tainan"}
hass_input_boolean_state{site="tainan", entity="input_boolean.closet_dehumidify"}
```

The Pi 5 Prometheus keeps 7 days. For anything longer use HA's own long-term statistics
(History, or a Statistics graph card), which go back to 2025-01 for the Dyson.

## Setup

1. In HA, Settings → People → add a user `prometheus`, not an administrator, local access only.
   Log in as it once, Profile → Security → create a long-lived access token. Log in as yourself
   again.
2. Add `configuration-snippet.yaml` to `/config/configuration.yaml` and the three automations to
   `/config/automations.yaml`, then restart HA.
3. Put `homeassistant_target` and `homeassistant_token` in `sites/tainan/terraform.tfvars`
   (see the example) and apply `sites/tainan`. The token stays in tfvars, never in git.
4. Check: `up{job="homeassistant", site="tainan"}` is 1, and the `hass_` series above exist.

The token is not limited to `/api/prometheus`: as a normal HA user it can read every entity and
call services such as `climate` and `switch`. It travels over plain HTTP on the IoT VLAN and sits
in the Alloy container's env on the NAS (`docker inspect`). Keep the user non-admin, and revoke
the token in HA (Profile → Security) if the NAS or the VLAN is ever suspect.
