#!/bin/bash

test -n "${DEBUG}" && {
  printenv
  echo "$@"
}

# Pre-startup
test -f /prestartup.sh && {
  chmod +x /prestartup.sh
  . /prestartup.sh
}

grep --quiet --extended-regexp "^dev:" /etc/group >/dev/null 2>&1 || { groupadd --gid 5001 dev; }
chgrp --recursive dev /builds /sources
chmod --recursive go+rwx /builds /sources
# Preparing user
export USER_NAME=${USER_NAME:-user}
id ${USER_NAME} >/dev/null 2>&1 || {
  export USER_PASS=${USER_PASS:-${USER_NAME}01}
  export USER_UID=${USER_UID:-6000}
  export USER_GID=${USER_GID:-${USER_UID}}
  getent group ${USER_NAME} || groupadd --gid ${USER_GID} ${USER_NAME}
  useradd --uid ${USER_UID} --gid ${USER_NAME} --groups sudo,dev --create-home --shell /bin/bash ${USER_NAME}
  echo "${USER_NAME}:${USER_PASS}" | chpasswd
  echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/10-${USER_NAME} && chmod 400 /etc/sudoers.d/10-${USER_NAME}
  touch /home/${USER_NAME}/.sudo_as_admin_successful
  echo 'export PATH=.:${PATH}' >>/home/${USER_NAME}/.bashrc
  echo "export PS1='\u@cross-gcc:\w\$ '" >>/home/${USER_NAME}/.bashrc
  echo "alias ll='ls -lart'" >>/home/${USER_NAME}/.bash_aliases
  echo "alias psx='ps -fu $USER'" >>/home/${USER_NAME}/.bash_aliases
  echo "alias g='which gcc g++ i686-w64-mingw32-gcc i686-w64-mingw32-g++ x86_64-w64-mingw32-gcc x86_64-w64-mingw32-g++ make i686-w64-mingw32-windres x86_64-w64-mingw32-windres wine wine64 java javac groovy rcedit.exe upx go lua luac node npm | sort -u 2> /dev/null'" >>/home/${USER_NAME}/.bash_aliases
  echo "alias rcedit='wine /usr/bin/rcedit.exe'" >>/home/${USER_NAME}/.bash_aliases && chmod +x /home/${USER_NAME}/.bash_aliases
  unset USER_NAME USER_PASS PASS USER_UID USER_GID
}
export DEFAULT_USER=${USER_NAME}

#echo "Preparing environment ..."
update-ca-certificates >/dev/null 2>&1
test -S /var/run/docker.sock && sudo groupmod --gid $(ls --numeric-uid-gid /var/run/docker.sock | awk '{print $4}') docker && sudo usermod --append --groups docker ${USER_NAME} && sudo chmod o+rw /var/run/docker.sock

# Preparing timezone
TZ=${TZ:-UTC}
test -f /usr/share/zoneinfo/${TZ} && {
  test -f /etc/localtime && rm --force /etc/localtime
  ln --symbolic --force /usr/share/zoneinfo/${TZ} /etc/localtime
}

which wine >/dev/null 2>&1 && {
  printf '#include <stdio.h>\n#include <stdlib.h>\nint main(int argc, char**argv) {\n   printf("☢ Hello world!\\n");\n  return 0;\n}\n' >/sources/hello.c
  i686-w64-mingw32-g++ -o /builds/hello /sources/hello.c
  wine /builds/hello >/dev/null 2>&1
  rm --force /sources/hello.c /builds/hello* >/dev/null 2>&1
}

# Preparing environment for Go
if [ -d /root/go ]; then
  export GOOS=${GOOS:-windows}
  export GOARCH=${GOARCH:-386}
  export GOPATH=${GOPATH:-/root/go}
  export GOROOT=${GOROOT:-/usr/local/go}
  export PATH=${PATH}:${GOPATH}/bin:${GOROOT}/bin
# { printf 'package main \nimport "fmt"\nfunc main() {\n  fmt.Println("Hello world!")\n}\n' > /sources/hello.go ; cd /sources && go build hello.go ; rm /sources/hello.go /sources/hello.exe > /dev/null 2>&1 ; }
fi

# Preparing environment for Lua
export PATH=${PATH}:/root/lua/bin

# Starting
which g >/dev/null 2>&1 && {
  echo "Available commands:"
  g
}

# Starting ssh server
which systemctl >/dev/null && {
  printf '[Unit]\nDescription=OpenBSD Secure Shell server\nDocumentation=man:sshd(8) man:sshd_config(5)\nAfter=network.target auditd.service\nConditionPathExists=!/etc/ssh/sshd_not_to_be_run\n\n[Service]\nEnvironmentFile=-/etc/default/ssh\nExecStartPre=/usr/sbin/sshd -t\nExecStart=/usr/sbin/sshd -D $SSHD_OPTS\nExecReload=/usr/sbin/sshd -t\nExecReload=/bin/kill -HUP $MAINPID\nKillMode=process\nRestart=on-failure\nRestartPreventExitStatus=255\nType=notify\nRuntimeDirectory=sshd\nRuntimeDirectoryMode=0755\n\n[Install]\nWantedBy=multi-user.target\nAlias=sshd.service\n' >/lib/systemd/system/ssh.service
}
/etc/init.d/ssh start >/dev/null
export PATH=.:${PATH}

# Post-startup
test -f /poststartup.sh && {
  chmod +x /poststartup.sh
  . /poststartup.sh
}

if [ -f /startup.sh ]; then
  chmod +x /startup.sh
  exec gosu $(id -u ${USER_NAME}) /startup.sh "$@"
elif [ $# -eq 0 ]; then
  exec gosu $(id -u ${USER_NAME}) /bin/bash
elif [ $# -eq 1 ]; then
  exec gosu $(id -u ${USER_NAME}) /bin/bash -c "$@"
else
  exec gosu $(id -u ${USER_NAME}) "$@"
fi
