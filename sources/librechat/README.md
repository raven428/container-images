# LibreChat container with Podman support

Rebased onto `node:24-trixie-slim` (Debian) to run a rootless podman runtime inside the container, enabling stdio MCP servers that spawn their own containers (e.g. `eduard256/ozon-mcp-server`, which needs a headless Chromium).

The `ozon` MCP server in `files/librechat.local.yaml` runs `podman run -i --rm --init --shm-size=1g ghcr.io/raven428/container-images/mcp-ozon:latest`. For that to work the outer LibreChat container must start with enough privileges and a UID mapping that lines up with `/etc/subuid` configured by `setup-podman.sh`.

## LibreChat Podman Quadlet

```ini
[Unit]
Description=main LibreChat
Wants=network-online.target
After=network-online.target

[Container]
WorkingDir=/app
Image=ghcr.io/raven428/container-images/librechat:999
EnvironmentFile=/etc/default/librechat
ContainerName=librechat
HostName=librechat
Network=slirp4netns:allow_host_loopback=true
Exec=node /app/entrypoint.js
PublishPort=127.0.0.1:3080:3080
PodmanArgs=--cidfile=%t/user/888/%N.cid --runtime runc --init
AddCapability=CAP_SYS_ADMIN
AddCapability=CAP_NET_ADMIN
AddDevice=/dev/fuse
AddDevice=/dev/net/tun
UIDMap=0:1:888
UIDMap=888:0:1
UIDMap=889:889:8999111
GIDMap=0:1:888
GIDMap=888:0:1
GIDMap=889:889:8999111

[Service]
User=podman
Group=podman
RestartSec=1
Restart=always
StartLimitInterval=0
SyslogIdentifier=librechat
TimeoutStopSec=22s
TimeoutStartSec=11m
Delegate=yes

[Install]
WantedBy=default.target
```

for this `{u,g}id`:

```bash
[~@shine-creek/13:57:49]
raven$ cat /etc/sub{g,u}id
raven:100000:9899999
podman:10000000:8999999
raven:100000:9899999
podman:10000000:8999999
[~@shine-creek/13:57:54]
raven$ id podman
uid=888(podman) gid=888(podman) groups=888(podman)
```
