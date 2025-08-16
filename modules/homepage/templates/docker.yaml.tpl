pi5-docker:
  socket: /var/run/docker.sock
  
macmini-docker:
  host: ${mac_mini_hostname}
  port: 2375
  # Uses existing dockerproxy container from homelab