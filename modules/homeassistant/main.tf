terraform {
  required_providers {
    docker = {
      source                = "kreuzwerker/docker"
      version               = "~> 3.0"
      configuration_aliases = [docker]
    }
  }
}

resource "docker_volume" "homeassistant_configuration" {
  name = "homeassistant_configuration"
}

resource "docker_image" "homeassistant" {
  name = "ghcr.io/home-assistant/home-assistant:stable"
}

resource "docker_container" "homeassistant" {
  image        = docker_image.homeassistant.image_id
  name         = "homeassistant"
  restart      = "unless-stopped"
  network_mode = "host"

  # Resource limits for stability
  memory      = var.memory_limit
  memory_swap = var.memory_limit * 2

  # Lifecycle management to prevent unnecessary recreation
  lifecycle {
    ignore_changes = [
      # Ignore Docker-managed attributes that don't affect functionality
      memory,
      memory_swap,
      # Docker normalises "60s" → "1m0s"; ignore to prevent perpetual in-place diff
      healthcheck,
    ]
    replace_triggered_by = [
      docker_image.homeassistant.image_id,
    ]
  }

  # Health check
  healthcheck {
    test         = ["CMD", "curl", "-f", "http://localhost:8123/"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  # Security capabilities instead of privileged mode
  capabilities {
    add = ["NET_ADMIN", "NET_RAW", "SYS_ADMIN"]
  }

  # Environment variables for HomeAssistant
  env = [
    "TZ=${var.timezone}",
    "HACS_ENABLED=${var.enable_hacs ? "true" : "false"}"
  ]

  # USB device access for Zigbee/Z-Wave dongles
  dynamic "devices" {
    for_each = var.enable_usb_devices ? [1] : []
    content {
      host_path      = "/dev/ttyUSB0"
      container_path = "/dev/ttyUSB0"
    }
  }

  dynamic "devices" {
    for_each = var.enable_usb_devices ? [1] : []
    content {
      host_path      = "/dev/ttyACM0"
      container_path = "/dev/ttyACM0"
    }
  }

  volumes {
    container_path = "/config"
    volume_name    = docker_volume.homeassistant_configuration.name
  }

  volumes {
    container_path = "/etc/localtime"
    host_path      = "/etc/localtime"
    read_only      = true
  }

  volumes {
    container_path = "/run/dbus"
    host_path      = "/run/dbus"
    read_only      = true
  }

  # Logging configuration
  log_opts = var.log_opts

  # Stop this container before docker-volume-backup archives /config.
  # Home Assistant uses a SQLite recorder database (home-assistant_v2.db) that
  # must be quiesced before copying to avoid a corrupt backup.
  labels {
    label = "docker-volume-backup.stop-during-backup"
    value = "true"
  }
}

resource "null_resource" "ha_prometheus_config" {
  triggers = {
    container_id = docker_container.homeassistant.id
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      # Exit early if the prometheus: block is already present (config volume persists
      # across container recreation, so this is the common path after a redeploy).
      if ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
          -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
          "docker exec homeassistant grep -q '^prometheus:' /config/configuration.yaml" 2>/dev/null; then
        echo "HA prometheus config already present, skipping"
        exit 0
      fi
      # Base64-encode the YAML block locally and decode+append inside the
      # container — avoids all SSH/docker-exec quoting complexity.
      BLOCK=$(printf '\nprometheus:\n' | base64 | tr -d '\n')
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "echo '$${BLOCK}' | base64 -d | docker exec --interactive homeassistant sh -c 'cat >> /config/configuration.yaml'"
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} docker restart homeassistant
      echo "HA prometheus config written, HA restarted"
    BASH
  }
}

# Inject a template sensor that exports the vacuum state as a numeric value.
# HA's Prometheus integration skips the vacuum domain because its state is a
# string (docked/cleaning/returning/…). A template sensor converts it to a
# number so Prometheus can store it.
#
# State mapping:  0=unknown  1=cleaning  2=returning  3=docked  4=paused  5=idle  6=error
resource "null_resource" "ha_vacuum_template_sensor" {
  triggers = {
    container_id = docker_container.homeassistant.id
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      if ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
          -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
          "docker exec homeassistant grep -q 'roborock_state_numeric' /config/configuration.yaml" 2>/dev/null; then
        echo "HA vacuum template sensor already present, skipping"
        exit 0
      fi
      BLOCK=$(printf '\ntemplate:\n  - sensor:\n      - name: "Roborock State Numeric"\n        unique_id: roborock_state_numeric\n        icon: mdi:robot-vacuum\n        state: >\n          {%% set s = states('"'"'vacuum.roborock_qrevo_c_pro'"'"') %%}\n          {%% if s == '"'"'cleaning'"'"' %%}1{%% elif s == '"'"'returning'"'"' %%}2{%% elif s == '"'"'docked'"'"' %%}3{%% elif s == '"'"'paused'"'"' %%}4{%% elif s == '"'"'idle'"'"' %%}5{%% elif s == '"'"'error'"'"' %%}6{%% else %%}0{%% endif %%}\n' | base64 | tr -d '\n')
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "echo '$${BLOCK}' | base64 -d | docker exec --interactive homeassistant sh -c 'cat >> /config/configuration.yaml'"
      ssh -i ~/.ssh/id_ed25519.rpi5 -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} docker restart homeassistant
      echo "HA vacuum template sensor written, HA restarted"
    BASH
  }

  depends_on = [null_resource.ha_prometheus_config]
}

# HACS (Home Assistant Community Store) installation
resource "null_resource" "hacs_installation" {
  count = var.enable_hacs ? 1 : 0

  triggers = {
    container_id = docker_container.homeassistant.id
    hacs_enabled = var.enable_hacs
  }

  # Install HACS via native ssh (avoids Terraform SSH client exhausting MaxAuthTries
  # when many keys are loaded in the agent — uses IdentitiesOnly with explicit key)
  provisioner "local-exec" {
    command = <<-BASH
      ssh -i ${var.ssh_private_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no \
        -p ${var.ssh_port} ${var.ssh_user}@${var.hostname} \
        "docker exec homeassistant bash -c 'if [ ! -d /config/custom_components/hacs ]; then echo Installing HACS...; cd /config && wget -O - https://get.hacs.xyz | bash -; else echo HACS already installed; fi'"
    BASH
  }

  depends_on = [docker_container.homeassistant]
}

# ─── n8n event bridge (Theme A Component 2, HA side) ────────────────────────
# Adds a rest_command HA can call, plus two ADDITIVE automations that log when
# Bambii's calming music turns on/off — the existing bambii_music_start/stop
# automations are left untouched. HA POSTs to the n8n webhook on the Mac Mini,
# which appends a #home-event bullet to the Obsidian daily note.
#
# Safety: both files are backed up before the append, the whole config is run
# through HA's check_config, and on any failure the files are rolled back and HA
# is NOT restarted — a bad edit can never take the family's HA down.
locals {
  ha_n8n_rest_command = join("\n", [
    "",
    "rest_command:",
    "  n8n_ha_event:",
    "    url: \"${var.n8n_webhook_url}\"",
    "    method: POST",
    "    content_type: \"application/json\"",
    "    payload: '{\"event\": \"{{ event }}\", \"detail\": \"{{ detail }}\", \"ts\": \"{{ now() }}\"}'",
    "",
  ])

  ha_n8n_bambii_automations = join("\n", [
    "",
    "- id: bambii_music_log_on",
    "  alias: \"Bambii Music - Log ON to n8n\"",
    "  trigger:",
    "    - platform: state",
    "      entity_id: input_boolean.bambii_music",
    "      to: \"on\"",
    "  action:",
    "    - service: rest_command.n8n_ha_event",
    "      data:",
    "        event: \"bambii_music_on\"",
    "        detail: \"calming music started\"",
    "  mode: single",
    "- id: bambii_music_log_off",
    "  alias: \"Bambii Music - Log OFF to n8n\"",
    "  trigger:",
    "    - platform: state",
    "      entity_id: input_boolean.bambii_music",
    "      to: \"off\"",
    "  action:",
    "    - service: rest_command.n8n_ha_event",
    "      data:",
    "        event: \"bambii_music_off\"",
    "        detail: \"calming music stopped\"",
    "  mode: single",
    "",
  ])
}

resource "null_resource" "ha_n8n_bridge_config" {
  triggers = {
    container_id = docker_container.homeassistant.id
    rest_command = local.ha_n8n_rest_command
    automations  = local.ha_n8n_bambii_automations
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      SSH="ssh -i ${var.ssh_private_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p ${var.ssh_port} ${var.ssh_user}@${var.hostname}"
      CHANGED=0

      # 1. rest_command -> configuration.yaml (idempotent on marker 'n8n_ha_event')
      if ! $${SSH} "docker exec homeassistant grep -q n8n_ha_event /config/configuration.yaml" 2>/dev/null; then
        echo "${base64encode(local.ha_n8n_rest_command)}" | base64 -d \
          | $${SSH} "docker exec -i homeassistant sh -c 'cp -n /config/configuration.yaml /config/configuration.yaml.n8nbak; cat >> /config/configuration.yaml'"
        CHANGED=1
      fi

      # 2. logging automations -> automations.yaml (idempotent on marker 'bambii_music_log_on')
      if ! $${SSH} "docker exec homeassistant grep -q bambii_music_log_on /config/automations.yaml" 2>/dev/null; then
        echo "${base64encode(local.ha_n8n_bambii_automations)}" | base64 -d \
          | $${SSH} "docker exec -i homeassistant sh -c 'cp -n /config/automations.yaml /config/automations.yaml.n8nbak; cat >> /config/automations.yaml'"
        CHANGED=1
      fi

      if [ "$${CHANGED}" = "0" ]; then
        echo "HA n8n bridge config already present, skipping"
        exit 0
      fi

      # 3. Validate the whole config; roll back BOTH files and skip the restart on failure.
      if ! $${SSH} "docker exec homeassistant python -m homeassistant --script check_config -c /config"; then
        echo "HA config check FAILED — rolling back n8n bridge changes, NOT restarting"
        $${SSH} "docker exec homeassistant sh -c 'test -f /config/configuration.yaml.n8nbak && mv /config/configuration.yaml.n8nbak /config/configuration.yaml; test -f /config/automations.yaml.n8nbak && mv /config/automations.yaml.n8nbak /config/automations.yaml'"
        exit 1
      fi

      $${SSH} "docker exec homeassistant sh -c 'rm -f /config/configuration.yaml.n8nbak /config/automations.yaml.n8nbak'"
      $${SSH} "docker restart homeassistant"
      echo "HA n8n bridge config written & validated, HA restarted"
    BASH
  }

  depends_on = [null_resource.ha_vacuum_template_sensor]
}

# ─── Alertmanager push (critical alerts -> phones) ──────────────────────────
# Alertmanager runs on this same Pi, so this path survives the Mac being down.
# local_only keeps the webhook on the LAN; notify.notify reaches every
# registered companion app without hardcoding a device name.
locals {
  ha_alert_automation = var.alert_webhook_id == "" ? "" : join("\n", [
    "",
    "- id: alertmanager_push",
    "  alias: \"Alertmanager - push firing alerts\"",
    "  trigger:",
    "    - platform: webhook",
    "      webhook_id: \"${var.alert_webhook_id}\"",
    "      allowed_methods:",
    "        - POST",
    "      local_only: true",
    "  action:",
    "    - service: notify.notify",
    "      data:",
    "        title: >-",
    "          {{ trigger.json.status | upper }}: {{ trigger.json.alerts[0].labels.alertname }}",
    "        message: >-",
    "          {{ trigger.json.alerts | length }} alert(s) on",
    "          {{ trigger.json.alerts[0].labels.instance | default('homelab') }} —",
    "          {{ trigger.json.alerts[0].annotations.summary | default('no summary') }}",
    "  mode: queued",
    "  max: 10",
    "",
  ])
}

resource "null_resource" "ha_alertmanager_push" {
  count = var.alert_webhook_id == "" ? 0 : 1

  triggers = {
    container_id = docker_container.homeassistant.id
    automation   = local.ha_alert_automation
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      SSH="ssh -i ${var.ssh_private_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p ${var.ssh_port} ${var.ssh_user}@${var.hostname}"

      if $${SSH} "docker exec homeassistant grep -q alertmanager_push /config/automations.yaml" 2>/dev/null; then
        echo "Alertmanager push automation already present, skipping"
        exit 0
      fi

      echo "${base64encode(local.ha_alert_automation)}" | base64 -d \
        | $${SSH} "docker exec -i homeassistant sh -c 'cp -n /config/automations.yaml /config/automations.yaml.ambak; cat >> /config/automations.yaml'"

      if ! $${SSH} "docker exec homeassistant python -m homeassistant --script check_config -c /config"; then
        echo "HA config check FAILED — rolling back the Alertmanager automation, NOT restarting"
        $${SSH} "docker exec homeassistant sh -c 'test -f /config/automations.yaml.ambak && mv /config/automations.yaml.ambak /config/automations.yaml'"
        exit 1
      fi

      $${SSH} "docker exec homeassistant sh -c 'rm -f /config/automations.yaml.ambak'"
      $${SSH} "docker restart homeassistant"
      echo "Alertmanager push automation written & validated, HA restarted"
    BASH
  }

  depends_on = [null_resource.ha_n8n_bridge_config]
}

# ─── iPhone monitoring sensors ───────────────────────────────────────────────
# Companion-app sensors are mostly strings, so the Prometheus integration only
# exports their change counters. These template sensors turn them into numbers
# Grafana can chart next to the battery level:
#
#   iPhone Network Type   -1=no connection  0=Wi-Fi  1=4G/LTE  2=5G  3=other cellular
#                         (iOS reports the radio on the SIM sensor's
#                         "Current Radio Technology", so that is the fallback)
#   iPhone Charging       1=charging or full  0=on battery
#   iPhone Slow Reports   counts taps on the companion-app Action "手機好慢"
#                         (ios.action_fired), one per "the phone feels slow now";
#                         the HA start trigger publishes 0 so the first tap
#                         has an earlier sample for changes()/increase()
#
# configuration.yaml already has a top-level `template:` key (Roborock sensor
# above) and a second one would replace it, so a small Python script keeps these
# items between marker comments at the top of that list and rewrites them when
# they change. Backup + check_config + rollback as in the n8n bridge.
locals {
  ha_iphone_connection_entity = "sensor.${var.iphone_entity_prefix}_connection_type"
  ha_iphone_sim_entity        = "sensor.${var.iphone_entity_prefix}_sim_1"
  ha_iphone_battery_entity    = "sensor.${var.iphone_entity_prefix}_battery_state"

  ha_iphone_network_sensor = join("\n", [
    "  # iphone-monitoring:begin (managed by terraform, rainforest-iot modules/homeassistant)",
    "  - sensor:",
    "      - name: \"iPhone Network Type\"",
    "        unique_id: iphone_network_type_numeric",
    "        icon: mdi:signal-cellular-3",
    "        availability: \"{{ has_value('${local.ha_iphone_connection_entity}') }}\"",
    "        state: >",
    "          {% set s = states('${local.ha_iphone_connection_entity}') %}",
    "          {% set t = (state_attr('${local.ha_iphone_connection_entity}', 'Cellular Technology') or state_attr('${local.ha_iphone_sim_entity}', 'Current Radio Technology') or '') | upper %}",
    "          {% if s == 'Wi-Fi' %}0",
    "          {% elif s == 'Cellular' and ('5G' in t or 'NR' in t) %}2",
    "          {% elif s == 'Cellular' and ('LTE' in t or '4G' in t) %}1",
    "          {% elif s == 'Cellular' %}3",
    "          {% else %}-1{% endif %}",
    "      - name: \"iPhone Charging\"",
    "        unique_id: iphone_charging_numeric",
    "        icon: mdi:battery-charging",
    "        availability: \"{{ has_value('${local.ha_iphone_battery_entity}') }}\"",
    "        state: \"{{ 1 if states('${local.ha_iphone_battery_entity}') in ['Charging', 'Full'] else 0 }}\"",
    "  - trigger:",
    "      - platform: event",
    "        event_type: ios.action_fired",
    "        event_data:",
    "          actionName: \"手機好慢\"",
    "      - platform: homeassistant",
    "        event: start",
    "    sensor:",
    "      - name: \"iPhone Slow Reports\"",
    "        unique_id: iphone_slow_reports",
    "        icon: mdi:snail",
    "        state_class: total_increasing",
    "        state: \"{{ (this.state | int(0)) + (1 if trigger.platform == 'event' else 0) }}\"",
    "  # iphone-monitoring:end",
  ])

  # Runs inside the container (python3 reads it from stdin). Drops the managed
  # region (and the pre-marker single-sensor copy from the first apply), then
  # inserts the current block right under `template:`. Exits 10 when the region
  # is already identical, non-zero without touching the file when there is no
  # top-level `template:` key.
  ha_iphone_network_insert = <<-PY
    import os, sys
    p = "/config/configuration.yaml"
    lines = open(p).read().split("\n")
    block = ${jsonencode(local.ha_iphone_network_sensor)}.split("\n")
    begin, end = block[0], block[-1]
    if begin in lines and end in lines:
        s, e = lines.index(begin), lines.index(end) + 1
        if lines[s:e] == block:
            sys.exit(10)
        del lines[s:e]
    legacy = '      - name: "iPhone Network Type"'
    if legacy in lines:
        s = lines.index(legacy)
        e = next((j for j in range(s + 1, len(lines))
                  if lines[j].startswith("      - ") or (lines[j].strip() and not lines[j].startswith("        "))),
                 len(lines))
        del lines[s:e]
    if "template:" not in lines:
        sys.exit("no top-level 'template:' key in configuration.yaml")
    t = lines.index("template:")
    lines[t + 1:t + 1] = block
    with open(p + ".tmp", "w") as f:
        f.write("\n".join(lines))
    os.replace(p + ".tmp", p)
  PY
}

resource "null_resource" "ha_iphone_network_sensor" {
  count = var.iphone_entity_prefix == "" ? 0 : 1

  triggers = {
    container_id = docker_container.homeassistant.id
    sensor       = local.ha_iphone_network_sensor
  }

  provisioner "local-exec" {
    command = <<-BASH
      set -e
      SSH="ssh -i ${var.ssh_private_key_path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -p ${var.ssh_port} ${var.ssh_user}@${var.hostname}"

      $${SSH} "docker exec homeassistant cp /config/configuration.yaml /config/configuration.yaml.iphonebak"
      RC=0
      echo "${base64encode(local.ha_iphone_network_insert)}" | base64 -d \
        | $${SSH} "docker exec -i homeassistant python3 -" || RC=$?
      if [ "$${RC}" = "10" ]; then
        $${SSH} "docker exec homeassistant rm -f /config/configuration.yaml.iphonebak"
        echo "iPhone monitoring sensors already up to date, skipping"
        exit 0
      elif [ "$${RC}" != "0" ]; then
        echo "iPhone sensor writer failed (rc=$${RC}) — restoring configuration.yaml"
        $${SSH} "docker exec homeassistant mv /config/configuration.yaml.iphonebak /config/configuration.yaml"
        exit "$${RC}"
      fi

      if ! $${SSH} "docker exec homeassistant python -m homeassistant --script check_config -c /config"; then
        echo "HA config check FAILED — rolling back the iPhone sensors, NOT restarting"
        $${SSH} "docker exec homeassistant mv /config/configuration.yaml.iphonebak /config/configuration.yaml"
        exit 1
      fi

      $${SSH} "docker exec homeassistant rm -f /config/configuration.yaml.iphonebak"
      $${SSH} "docker restart homeassistant"
      echo "iPhone monitoring sensors written & validated, HA restarted"
    BASH
  }

  # Serialized after the other config writers: they all edit and restart HA.
  depends_on = [null_resource.ha_alertmanager_push]
}
