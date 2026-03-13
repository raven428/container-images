# Opencode container with Podman support

## Opencode Podman Quadlet

```bash
cat  ~raven/.config/containers/systemd/opencode-main.container
[Unit]
Description=main Opencode
Wants=network-online.target
After=network-online.target

[Container]
User=coder
WorkingDir=/workspace
Image=ghcr.io/raven428/container-images/opencode-ubuntu-22_04:999
UserNS=keep-id:uid=1000,gid=1000
Volume=%h/bin:/home/coder/bin
Volume=%h/git:/workspace/github
Volume=%h/vscode:/workspace/vscode
Volume=%h/.local:/home/coder/.local
Volume=%h/.claude:/home/coder/.claude
Volume=%h/.cache/opencode:/home/coder/.cache/opencode
Volume=%h/.config/opencode:/workspace/coder/config/opencode
Volume=%h/volumes/home/coder:/home/coder
Volume=/srv/data/podman/coder:/srv/data/podman/coder
Volume=/srv/data/podman/opencode-root:/var/lib/containers
Exec=/usr/local/bin/opencode web --hostname 0.0.0.0 --port 4096 --log-level DEBUG --print-logs
Environment=XDG_CONFIG_HOME=/workspace/coder/config
EnvironmentFile=/etc/default/opencode-main
PodmanArgs=--device /dev/fuse
ContainerName=opencode-main
HostName=opencode-main
PublishPort=4096:4096
AddCapability=CAP_SYS_ADMIN

[Service]
RestartSec=1
Restart=always
StartLimitInterval=0
SyslogIdentifier=opencode-main
TimeoutStopSec=22s
TimeoutStartSec=11m
Delegate=yes

[Install]
WantedBy=default.target
```
