pi5-docker:
  socket: /var/run/docker.sock
  
macmini-docker:
  host: ${mac_mini_ip}
  port: 2375
  # Uses Mac Mini IP directly to avoid mDNS issues in container