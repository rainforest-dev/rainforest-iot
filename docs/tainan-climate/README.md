# Tainan bedroom: humidity, closet mould and the AC

The bedroom closet at the Tainan house has mould. There is no dehumidifier
in that room, so the Panasonic AC (`climate.leng_qi_ji`, CS-QX50FA2, `panasonic_smart_app`)
does the drying, driven by the Dyson HP09's humidity sensor.

```
sensor.dyson_hp09_humidity > 65% → AC dry mode at 26 °C → < 55% or 3 h → AC off → 乾燥防霉 dries the coil
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

- `closet_dehumidify_start`: humidity above 65% for 15 minutes (re-checked every 30 minutes),
  room above 20 °C, AC off, and at least an hour since the last run. Sets dry mode, 26 °C, and
  turns 乾燥防霉 on while the AC is on.
- `closet_dehumidify_stop`: below 55% for 10 minutes, or after 3 hours, re-checked every 10
  minutes so a restart mid-run cannot leave the AC on. Turns the AC off only if it is still in
  dry mode.
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
