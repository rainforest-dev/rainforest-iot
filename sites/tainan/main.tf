# Separate root: the Docker provider dials the NAS on every plan, even with no changes.
provider "docker" {
  host = "ssh://${var.nas_ssh_user}@${var.nas_ssh_host}"
}

module "site" {
  source = "../../modules/remote-site"

  site             = "tainan"
  remote_write_url = var.remote_write_url
  unifi_url        = var.unifi_url
  unifi_api_key    = var.unifi_api_key
  unifi_user       = var.unifi_user
  unifi_pass       = var.unifi_pass
  snmp_community   = var.ap_snmp_community

  snmp_v3 = {
    username      = var.snmp_v3_username
    auth_password = var.snmp_v3_auth_password
    priv_password = var.snmp_v3_priv_password
  }

  snmp_targets = {
    nas = {
      address = "host.docker.internal"
      module  = "synology,if_mib"
      auth    = "v3"
    }
    ap_nwa130be = {
      address = var.ap_snmp_address
      module  = "if_mib"
      auth    = var.ap_snmp_auth
    }
  }

  isp_ping_targets = {
    hinet-dns  = "168.95.1.1"
    cloudflare = "1.1.1.1"
    google-dns = "8.8.8.8"
  }

  lan_ping_targets = var.lan_ping_targets
  node_targets     = var.node_targets
}
