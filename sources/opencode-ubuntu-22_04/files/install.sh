#!/usr/bin/env bash
set -ueo pipefail
# podman
/files/shared/podman.sh
# generic packages
export DEBIAN_FRONTEND=noninteractive
apt-get install -y --no-install-recommends \
  bash apt-utils apt-file ca-certificates ethtool bash-completion tcpdump less xxd \
  vim tmux screen curl wget rsync xz-utils pixz nmap atop htop traceroute sudo \
  whois iotop netcat-openbsd telnet bind9-utils bind9-host bind9-dnsutils gdisk p7zip \
  iftop nmon reptyr psmisc jq git bc lsof progress pv tree iproute2 net-tools \
  hostname dmidecode groff-base hdparm lshw iputils-ping iputils-arping locales \
  secure-delete moreutils less acl lz4 lzop lzma zstd unzip mtr patch ripgrep file \
  redis-tools mysqltuner mariadb-client postgresql-client nftables iptables \
  binutils bsdextrautils openssh-client fuse-overlayfs libcap2-bin squashfs-tools \
  squashfuse debootstrap xfsprogs qemu-system-x86 qemu-utils expect
apt-get upgrade -y
cat >/etc/locale.gen <<'EOF'
en_US.UTF-8 UTF-8
en_GB.UTF-8 UTF-8
EOF
locale-gen
pam_line='account sufficient pam_succeed_if.so uid = 0 use_uid quiet'
sed -i "/^auth[[:space:]]\+sufficient[[:space:]]\+pam_rootok\.so$/a ${pam_line}" \
  /etc/pam.d/su

# direct download
CRUN_VER='1.25.1'
mkdir -vp /usr/local/bin
cd /usr/local/bin
curl -sLo kubectl "https://dl.k8s.io/release/$(curl -L -s \
  https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -sLo yq \
  https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
curl -sLo crun "https://github.com/containers/crun/releases/download/${CRUN_VER}/\
crun-${CRUN_VER}-linux-amd64"
chmod -v 755 kubectl yq crun
curl -sL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
curl -sL "https://github.com/fullstorydev/grpcurl/releases/download/v1.9.1/grpcurl\
_1.9.1_linux_amd64.deb" -o /files/grpcurl.deb && dpkg -i /files/grpcurl.deb

# image configuration
rm -Rf /root
mv -v /files/shared/profile-dmisu /root
# shellcheck disable=2016
find /root -type d -print0 | xargs chmod 755
find /root -type f -print0 | xargs chmod 644
update-ca-certificates
mv -vf /files/shared/sudoers /etc/sudoers
chmod 400 /etc/sudoers

# coder user (maps to host raven uid=1000)
# remove any existing user/group with uid/gid 1000
existing_user="$(getent passwd 1000 | cut -d: -f1 || true)"
if [[ -n "${existing_user}" ]]; then
  userdel "${existing_user}"
fi
existing_group="$(getent group 1000 | cut -d: -f1 || true)"
if [[ -n "${existing_group}" ]]; then
  groupdel "${existing_group}"
fi
groupadd -g 1000 coder
useradd -u 1000 -g 1000 -s /bin/bash -d /home/coder coder
usermod -aG sudo coder
mkdir -vp /workspace
chown coder:coder /workspace
# newuidmap/newgidmap: set capabilities instead of setuid (matches podman/stable)
chmod 0755 /usr/bin/newuidmap /usr/bin/newgidmap
setcap cap_setuid+ep /usr/bin/newuidmap
setcap cap_setgid+ep /usr/bin/newgidmap
# subuid/subgid: range visible inside outer container (uid 1..65536),
# with a hole at 1000 (coder's own uid)
printf 'root:1001:98998\ncoder:100000:899999\n' | tee /etc/subuid /etc/subgid
# system-wide containers.conf for nested podman
mkdir -vp /etc/containers
cat <<'EOF' >/etc/containers/containers.conf
[containers]
netns = "host"
userns = "host"
ipcns = "host"
utsns = "host"
cgroupns = "host"
cgroups = "disabled"
log_driver = "k8s-file"

[engine]
cgroup_manager = "cgroupfs"
events_logger = "file"
runtime = "crun"
EOF
chmod 644 /etc/containers/containers.conf
# storage.conf: enable fuse-overlayfs and shared image store
cat <<'EOF' >/etc/containers/storage.conf
[storage]
driver = "overlay"
graphroot = "/var/lib/containers/storage"
runroot = "/run/containers/storage"
[storage.options]
additionalimagestores = [
  "/var/lib/shared",
]
[storage.options.overlay]
mount_program = "/usr/bin/fuse-overlayfs"
mountopt = "nodev,fsync=0"
EOF
# shared image store dirs
mkdir -vp \
  /var/lib/shared/overlay-images \
  /var/lib/shared/overlay-layers \
  /var/lib/shared/vfs-images \
  /var/lib/shared/vfs-layers
touch \
  /var/lib/shared/overlay-images/images.lock \
  /var/lib/shared/overlay-layers/layers.lock \
  /var/lib/shared/vfs-images/images.lock \
  /var/lib/shared/vfs-layers/layers.lock
# per-user containers config for coder
mkdir -vp /home/coder/.cache /workspace/coder/config/containers /srv/data/podman/coder
cat <<'EOF' >/workspace/coder/config/containers/containers.conf
[containers]
volumes = [
  "/proc:/proc",
]
default_sysctls = []
EOF
cat <<'EOF' >/workspace/coder/config/containers/storage.conf
[storage]
driver = "overlay"
graphRoot = "/srv/data/podman/coder"
EOF
chown -R coder:coder /home/coder /workspace/coder /srv/data/podman/coder
mkdir -vp /root/.config/containers
cp -v /workspace/coder/config/containers/containers.conf /root/.config/containers

# cleanup
rm -Rf /usr/share/doc /usr/share/man /var/lib/apt/lists/* /root/.cache/pip /files
