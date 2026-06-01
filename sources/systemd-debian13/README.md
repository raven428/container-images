# Image of Debian 13 (trixie) with systemd entry

Runs systemd 257 as PID 1 in a standard Docker container **without** any
extra flags, capabilities, or host modifications. Works on Docker hosts with
cgroup v2 (Linux ≥ 5.2).

The image contains a binary patch of `libsystemd-shared-257.so` that makes
`cg_create` and `cg_attach` silently succeed when `/sys/fs/cgroup` is
read-only (the default for unprivileged Docker containers). Systemd still
manages services normally; it just cannot actually track processes in cgroups.

The full systemd journal is streamed to stdout via `journalctl -f -b` started
by entrypoint, so `docker logs` shows all boot and service messages.

## Manual launch

```bash
cont_name='test-container'
/usr/bin/env docker run --name "${cont_name}" -d \
  host.tld/registry/path/debian-systemd-13:latest
count=7
while ! /usr/bin/env docker exec "${cont_name}" systemctl status; do
  echo "waiting container ready, left [$count] tries"
  count=$((count - 1))
  if [[ $count -le 0 ]]; then
    echo 'container failed'
    exit 1
  fi
  sleep 1
done
if [[ $count -gt 0 ]]; then
  echo 'container ready'
fi
```

## Molecule configuration

`molecule.yml`:

```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: "tests-container"
    image: "host.tld/registry/path/debian-systemd-13:latest"
provisioner:
  name: ansible
  env:
    ANSIBLE_VERBOSITY: 1
  inventory:
    links:
      group_vars: "group_vars"
  playbooks:
    create: create.yaml
    prepare: prepare.yaml
    converge: converge.yaml
    destroy: destroy.yaml
  config_options:
    defaults:
      remote_tmp: /tmp
      jinja2_extensions: jinja2.ext.do
verifier:
  name: ansible
scenario:
  create_sequence:
    - dependency
    - create
```

## План: пересборка libsystemd-shared из исходников

### Проблема текущего подхода

Сейчас используется бинарный патч `.so` – поиск конкретных байт по смещениям
и замена. При любом обновлении пакета systemd (включая security-фиксы)
смещения уплывают и патч ломается. Нужно вручную искать новые offsets через
objdump.

### Целевая архитектура

```
sources/
├── pabuilder-debian12/           ← сборочный образ для bookworm
│   ├── Dockerfile
│   └── vars.sh
├── pabuilder-debian13/           ← сборочный образ для trixie
│   ├── Dockerfile
│   └── vars.sh
├── systemd-debian12/             ← финальный образ (multi-stage)
│   ├── Dockerfile                ← FROM pabuilder-debian12 AS builder
│   ├── patches/
│   │   └── 01-cgroup-noop.patch
│   └── ...                         + FROM debian:bookworm-slim
└── systemd-debian13/             ← финальный образ (multi-stage)
    ├── Dockerfile                ← FROM pabuilder-debian13 AS builder
    ├── patches/
    │   ├── 01-cgroup-noop.patch
    │   └── 02-posix-spawn-fallback.patch
    └── ...                         + FROM debian:trixie-slim
```

### Образы pabuilder-debian*

Каждый `pabuilder-debian*` – это универсальный сборочный образ для пакетов
соответствующего релиза Debian:

- Base: `debian:${DISTRO}-slim`
- Установлены: `build-essential`, `dpkg-dev`, `devscripts`, `fakeroot`,
  `debhelper`
- Build-dep для конкретного пакета ставится при использовании в
  multi-stage сборке

Эти образы публикуются в ghcr.io как обычные контейнеры через существующий
workflow `containers.yaml`. Пригодны для сборки любых пакетов, не только
systemd.

### Образы systemd-debian*

Multi-stage Dockerfile:

```dockerfile
FROM ghcr.io/raven428/pabuilder-debian13:latest AS builder
RUN apt-get update && apt-get build-dep -y systemd && \
  apt-get source systemd
COPY patches/ /patches/
RUN cd systemd-* && \
  for p in /patches/*.patch; do patch -p1 < "$p"; done && \
  dpkg-buildpackage -b -uc -us -j$(nproc)

FROM debian:trixie-slim
RUN apt-get update && apt-get install -y systemd openssh-server ...
COPY --from=builder /libsystemd-shared_*.deb /tmp/
RUN dpkg -i /tmp/libsystemd-shared_*.deb && rm /tmp/*.deb
...
```

При сборке `systemd-debian13`:
1. Берётся готовый `pabuilder-debian13` (уже содержит базовые сборочные
   инструменты)
2. Ставятся build-dep для systemd, скачиваются исходники
3. Применяются патчи из `systemd-debian13/patches/`
4. Собирается `.deb`
5. Из builder-стадии копируется `.deb` в финальный образ
6. Устанавливается поверх стандартного systemd

### Текстовые патчи

Патчи лежат в директории `sources/systemd-debian*/patches/` соответствующего
контейнера и применяются при сборке в builder-стадии.

**01-cgroup-noop.patch** (общий для 252 и 257):

Файл: `src/shared/cgroup-setup.c`

- `cg_create()`: после `mkdir_parents()` и `mkdir()` – если ошибка
  `EROFS`/`EPERM`/`EACCES`, вернуть 0 (притвориться что cgroup уже
  существует)
- `cg_attach()`: после `write_string_file()` – если ошибка
  `EROFS`/`EPERM`/`EACCES`/`ENOENT`, вернуть 0

```diff
--- a/src/shared/cgroup-setup.c
+++ b/src/shared/cgroup-setup.c
@@ -330,10 +330,14 @@ int cg_create(const char *controller, const char *path) {
 
         r = mkdir_parents(fs, 0755);
         if (r < 0)
-                return r;
+                if (!IN_SET(r, -EROFS, -EPERM, -EACCES))
+                        return r;
 
         r = RET_NERRNO(mkdir(fs, 0755));
-        if (r == -EEXIST)
+        if (IN_SET(r, -EROFS, -EPERM, -EACCES))
+                return 0;
+
+        if (r == -EEXIST)
                 return 0;
         if (r < 0)
                 return r;
@@ -370,6 +374,8 @@ int cg_attach(const char *controller, const char *path, pid_t pid) {
         r = write_string_file(fs, c, WRITE_STRING_FILE_DISABLE_BUFFER);
         if (r == -EOPNOTSUPP && cg_is_threaded(path) > 0)
                 return -EUCLEAN;
+        if (IN_SET(r, -EROFS, -EPERM, -EACCES, -ENOENT))
+                return 0;
         if (r < 0)
                 return r;
```

**02-posix-spawn-fallback.patch** (только для 257+):

Файл: `src/basic/process-util.c`

- `posix_spawn_wrapper()`: если `open()` cgroup-директории упал – обнулить
  `cgroup` параметр и перейти к spawn без `CLONE_INTO_CGROUP`. Caller
  сделает `cg_attach()` самостоятельно (который тоже пропатчен)

```diff
--- a/src/basic/process-util.c
+++ b/src/basic/process-util.c
@@ -2108,8 +2108,11 @@ int posix_spawn_wrapper(
                 if (r < 0)
                         return r;
 
                 cgroup_fd = open(resolved_cgroup, O_PATH|O_DIRECTORY|O_CLOEXEC);
-                if (cgroup_fd < 0)
-                        return -errno;
+                if (cgroup_fd < 0) {
+                        /* cgroup dir does not exist (patched cg_create fakes success).
+                         * Fall back to spawning without CLONE_INTO_CGROUP. */
+                        goto skip_cgroup;
+                }
 
                 r = posix_spawnattr_setcgroup_np(&attr, cgroup_fd);
                 if (r != 0)
@@ -2117,6 +2120,7 @@ int posix_spawn_wrapper(
 
                 flags |= POSIX_SPAWN_SETCGROUP;
         }
+skip_cgroup:
 #endif
 
         r = posix_spawnattr_setflags(&attr, flags);
```

### Зависимости сборки (vars.sh)

```bash
DEPENDS='pabuilder-debian13/'
```

Существующий `_shared/_all/build.sh` уже поддерживает `DEPENDS` – сначала
соберёт `pabuilder-debian13`, потом `systemd-debian13`.

### Порядок в CI (containers.yaml)

Матрица определяется автоматически из директорий. Зависимости разрешаются
через `DEPENDS` в `vars.sh`:

1. `pabuilder-debian12` → собирается первым
2. `systemd-debian12` → `DEPENDS='pabuilder-debian12/'`, использует его
   как builder-стадию
3. Аналогично для debian13

### Преимущества перед бинарным патчем

- Патч текстовый, читаемый, легко ревьюить
- Переживает minor/security обновления systemd (пока функции не
  переписали)
- При несовместимом изменении – сборка упадёт с понятной ошибкой `patch`
  (а не молча соберёт сломанный образ)
- Не нужно вручную искать offsets через objdump
- Полноценный `.deb` – можно использовать и вне Docker
