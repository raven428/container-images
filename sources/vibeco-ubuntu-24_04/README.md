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
Group=coder
GroupAdd=sudo,tcpdump,root
WorkingDir=/workspace
Image=ghcr.io/raven428/container-images/vibeco-ubuntu-24_04:999
Volume=%h/bin:/home/coder/bin
Volume=%h/git:/workspace/github
Volume=%h/vscode:/workspace/vscode
Volume=%h/.local:/home/coder/.local
Volume=%h/.claude:/home/coder/.claude
Volume=%h/.cache/opencode:/home/coder/.cache/opencode
Volume=%h/.cache/claude-cli-nodejs:/home/coder/.cache/claude-cli-nodejs
Volume=%h/.config/opencode:/workspace/coder/config/opencode
Volume=%h/volumes/home/coder:/home/coder
Volume=/srv/data/podman/coder:/srv/data/podman/coder
Volume=/srv/data/podman/opencode-root:/var/lib/containers
Exec=/home/coder/bin/opencode web --hostname 0.0.0.0 --port 4096 --log-level DEBUG --print-logs
Environment=XDG_CONFIG_HOME=/workspace/coder/config
EnvironmentFile=/etc/default/opencode-main
ContainerName=opencode-main
HostName=opencode-main
AddHost=opencode-main:127.0.0.1
Network=host
AddCapability=CAP_SYS_ADMIN
AddCapability=CAP_NET_ADMIN
AddDevice=/dev/kvm
AddDevice=/dev/fuse
UIDMap=0:1:1000
UIDMap=1000:0:1
UIDMap=1001:1001:9898999
GIDMap=0:1:1000
GIDMap=1000:0:1
GIDMap=1001:1001:9898999

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
