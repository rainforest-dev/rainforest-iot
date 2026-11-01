locals {
  _fleet_net_filter = "device!~\"lo.*|veth.*|br.*|docker.*|tunl.*|cali.*|flannel.*|cni.*|utun.*|bridge.*|anpi.*|awdl.*|llw.*|ap.*|gif.*|stf.*|tailscale.*\""
  _fleet_windows    = "job=\"windows-node\""
  _fleet_nas        = "job=\"snmp\",site=\"tainan\",target=\"nas\""

  _fleet_node_hosts = {
    "rainforest-mini" = { selector = "job=\"mac-mini-node\"", site = "taipei", os = "macos" }
    "rainforest-air"  = { selector = "job=\"macbook-node\"", site = "mobile", os = "macos" }
    "raspberrypi-5"   = { selector = "job=\"node-exporter\"", site = "taipei", os = "linux" }
    "raspberrypi-4"   = { selector = "job=\"site-node\",site=\"tainan\",instance=\"raspberrypi-4\"", site = "tainan", os = "linux" }
  }

  _fleet_node_devices = {
    for device, host in local._fleet_node_hosts : device => {
      site   = host.site
      os     = host.os
      online = "max(up{${host.selector}}) or on() vector(0)"
      cpu    = "100 - avg(rate(node_cpu_seconds_total{${host.selector},mode=\"idle\"}[5m])) * 100"
      memory = (host.os == "macos"
        ? "sum(node_memory_internal_bytes{${host.selector}} / node_memory_total_bytes{${host.selector}})"
      : "sum(1 - node_memory_MemAvailable_bytes{${host.selector}} / node_memory_MemTotal_bytes{${host.selector}})")
      disk_free = "sum(node_filesystem_avail_bytes{${host.selector},mountpoint=\"/\"}) / sum(node_filesystem_size_bytes{${host.selector},mountpoint=\"/\"})"
      net_rx    = "sum(rate(node_network_receive_bytes_total{${host.selector},${local._fleet_net_filter}}[5m]))"
      net_tx    = "sum(rate(node_network_transmit_bytes_total{${host.selector},${local._fleet_net_filter}}[5m]))"
    }
  }

  _fleet_devices = merge(local._fleet_node_devices, {
    "rainforest-windows" = {
      site      = "taipei"
      os        = "windows"
      online    = "max(up{${local._fleet_windows}}) or on() vector(0)"
      cpu       = "100 - avg(rate(windows_cpu_time_total{${local._fleet_windows},mode=\"idle\"}[5m])) * 100"
      memory    = "1 - sum(windows_memory_available_bytes{${local._fleet_windows}}) / sum(windows_memory_physical_total_bytes{${local._fleet_windows}})"
      disk_free = "sum(windows_logical_disk_free_bytes{${local._fleet_windows},volume=\"C:\"}) / sum(windows_logical_disk_size_bytes{${local._fleet_windows},volume=\"C:\"})"
      net_rx    = "sum(rate(windows_net_bytes_received_total{${local._fleet_windows}}[5m]))"
      net_tx    = "sum(rate(windows_net_bytes_sent_total{${local._fleet_windows}}[5m]))"
    }
    "rainforest-nas" = {
      site      = "tainan"
      os        = "dsm"
      online    = "max(up{${local._fleet_nas}}) or on() vector(0)"
      disk_free = "sum(raidFreeSize{${local._fleet_nas}}) / sum(raidTotalSize{${local._fleet_nas}})"
      net_rx    = "sum(rate(ifHCInOctets{${local._fleet_nas},ifDescr=~\"eth.*\"}[5m]))"
      net_tx    = "sum(rate(ifHCOutOctets{${local._fleet_nas},ifDescr=~\"eth.*\"}[5m]))"
    }
  })

  _fleet_records = {
    online    = "fleet:online:bool"
    cpu       = "fleet:cpu_busy:percent"
    memory    = "fleet:memory_used:ratio"
    disk_free = "fleet:disk_free:ratio"
    net_rx    = "fleet:network_receive:bytes_per_second"
    net_tx    = "fleet:network_transmit:bytes_per_second"
  }

  fleet_rules = flatten([
    for device, series in local._fleet_devices : [
      for metric, record in local._fleet_records : {
        record = record
        expr   = series[metric]
        labels = { device = device, site = series.site, os = series.os }
      } if contains(keys(series), metric)
    ]
  ])
}

resource "kubernetes_config_map" "grafana_dashboard_fleet" {
  metadata {
    name      = "grafana-fleet"
    namespace = var.namespace
    labels    = { grafana_dashboard = "1" }
  }
  data = {
    "fleet.json" = file("${path.module}/dashboards/fleet.json")
  }
}
