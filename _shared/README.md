# Реструктуризация `_shared` по фичам

Документ описывает целевую организацию общей части сборочной инфраструктуры
и пошаговый план миграции. Цель – сделать так, чтобы изменение любого файла
в `_shared` или `podman.sh` триггерило пересборку только тех образов,
которые реально зависят от изменённой сущности, а не всех 34 контейнеров
сразу.

---

## 1. Контекст проблемы

Текущая фильтрация diff находится в `_shared/_all/vars.sh:36-64`. На push
или PR `_shared/_all/matrix.sh:7` source'ит `vars.sh`, тот формирует
`IMAGES_DIRS` и возвращает в джоб `define-matrix` уже отфильтрованный
список. То есть **pipeline уже использует diff‑фильтрацию**, проблема не в
отсутствии фильтра.

Проблема в трёх грубых фолбэках:

1. **`_shared/_all/vars.sh:47-50`** – если в diff есть хоть один путь,
   не начинающийся с `sources/` (то есть любая правка в `_shared/`),
   `source_dirs='sources/*'` – пересборка вообще всего. Детектор не
   различает, какие именно файлы `_shared/` поменялись и кто от них зависит.

2. **`_shared/_all/vars.sh:42-44`** – если diff пустой, выполняется
   `find sources/* -type f` – снова пересборка всего. В GitHub Actions
   на push в master это срабатывает почти всегда: `vars.sh:25-28`
   сравнивает `remotes/origin/master` с `.` (текущий HEAD после checkout),
   а после checkout они идентичны – diff пустой.

3. **Слепое пятно для `podman.sh`** – файл в корне репо копируется в 6
   образов (`ansible-appimage`, `ansible-builder`, `ansible-ubuntu`,
   `podman-ubuntu-22_04`, `podman-ubuntu-24_04`, `vibeco-ubuntu-24_04`),
   но в diff‑фильтре `_shared/_all/vars.sh:39` учтены только пути
   `_shared/` и `sources/`. Правка `podman.sh` в текущей логике не
   триггерит вообще ничего.

---

## 2. Текущее состояние `_shared`

```text
_shared/
├── _all/
│   ├── appimage.sh
│   ├── build.sh
│   ├── matrix.sh
│   ├── push.sh
│   └── vars.sh
├── install/
│   ├── ansible/
│   ├── coder.sh
│   ├── docker.sh
│   ├── openwrt/
│   ├── profile.sh
│   ├── systemd2docker/
│   └── texlive-appimage.sh
├── test/
│   └── systemd/
│       └── test.sh
├── prepare2check.sh
├── sudoers
└── vars.sh
```

Файлы внутри `sources/<image>/_shared/` в репозитории не лежат –
см. `.gitignore`:

```text
/sources/*/_shared
```

То есть `_shared` копируется в образ на этапе подготовки контекста сборки
через `sources/<image>/vars.sh`, а Podman забирает его через
`COPY _shared /files/shared` или `/files` (единообразия нет).

Файл `podman.sh` в корне репо занимает отдельное место: не входит ни в
`_shared/`, ни в `sources/`, но используется как общая зависимость.

---

## 3. Кто что использует сейчас

| Образ | Что берёт из `_shared` и не только | Тип |
|---|---|---|
| `ansible-06..11` | **весь `_shared`** + точечно `install/ansible/*` в `files/` | полный |
| `ansible-ubuntu` | весь `_shared` + `podman.sh` | полный |
| `ansible-builder` | весь `_shared` + `podman.sh` + чужой `install.sh` | полный |
| `ansible-appimage` | весь `_shared` + чужой `install.sh` | полный |
| `docker-ansible-06..11` | весь `_shared` + образ `ansible-XX` как base | полный |
| `systemd-debian12` | `install/systemd2docker/*`, `test/systemd/*`, `_all/*` | точечный |
| `systemd-debian13` | `install/systemd2docker/*`, `test/systemd/*`, `_all/*` | точечный |
| `systemd-ubuntu-22_04` | весь `_shared` + `test/systemd` | полный |
| `docker-ubuntu-22_04` | весь `_shared` + `test/systemd` | полный |
| `victim-ubuntu-22_04` | весь `_shared` + `test/systemd` | полный |
| `linters-ubuntu-22_04` | весь `_shared` + явно `prepare2check.sh` в Dockerfile | полный |
| `utils-ubuntu-22_04` | весь `_shared` + `install/profile.sh` | полный |
| `vibeco-ubuntu-24_04` | весь `_shared` + `install/profile.sh` + `podman.sh` | полный |
| `owrt-mtk-filogic-24_10_1` | `install/openwrt/*` | точечный |
| `owrt-rock-armv8-24_10_1` | `install/openwrt/*` | точечный |
| `owrt-sxi-cora53-24_10_1` | `install/openwrt/*` | точечный |
| `texlive-myminimal` | весь `_shared` + `install/texlive-appimage.sh` | полный |
| `omniroute` | только `_shared/vars.sh` (функция `checkout_upstream`) | точечный |
| `librechat` | только `_shared/vars.sh` (функция `checkout_upstream`) | точечный |
| `builder-kitty` | ничего: `vars.sh` только `rm -rf`; Dockerfile `COPY files` без `_shared` | точечный |
| `mkosi-26_0-ubuntu-24_04` | ничего: `vars.sh` пустой | точечный |
| `opencode-ubuntu-22_04` | ничего: только пустой `_shared/` артефакт | точечный |
| `podman-ubuntu-22_04` | `_shared` не копирует; зависит от `podman.sh` | точечный |
| `podman-ubuntu-24_04` | `_shared` не копирует; зависит от `podman.sh` | точечный |

**Итог:** 5 образов не зависят от `_shared/`, но `podman-ubuntu-*` при
этом зависят от `podman.sh` в корне репо. Ещё 8 можно сделать точечными
без реструктуризации: 3 openwrt + omniroute + librechat + 3
systemd-debian*. Остальные 21 делают `cp -rf _shared ...` целиком и до
Фазы 4 остаются на фолбэке «зависит от всего» – но только если у них не
мигрировать `SHARED_FEATURES` (см. Фазу 1 в разделе 9).

---

## 4. Целевая структура `_shared`

Идея: выделить независимые подобласти (фичи), каждая из которых
самодостаточна и не ссылается на соседей. Корневая `base/` содержит
сборочный каркас и общие утилиты, от которого зависят абсолютно все
образы.

```text
_shared/
├── base/
│   ├── _all/
│   │   ├── appimage.sh
│   │   ├── build.sh
│   │   ├── copy-shared.sh        # унифицированный копировщик
│   │   ├── matrix.sh
│   │   ├── push.sh
│   │   └── vars.sh               # переменные окружения, diff-фильтр
│   ├── git-helpers.sh            # бывшая функция checkout_upstream
│   ├── python-env.sh             # бывшие PYTHON_VERSION, PYENV_ROOT
│   ├── prepare2check.sh
│   └── sudoers
├── ansible/
│   ├── Dockerfile
│   ├── ansible-docker.sh
│   ├── ansible-lint.yaml
│   ├── async-check.diff
│   ├── build-appimage.sh
│   ├── build.sh
│   ├── check-syntax.sh
│   ├── common.sh
│   ├── configure.sh
│   ├── flush-line.diff
│   ├── style/
│   └── yamllint.yaml
├── coder/
│   └── coder.sh
├── docker/
│   └── docker.sh
├── openwrt/
│   ├── filogic.diff
│   ├── install.sh
│   ├── rock-armv8.diff
│   └── sxi-cora53.diff
├── profile/
│   └── profile.sh
├── systemd/
│   ├── apt-sources.sh
│   ├── build.sh
│   ├── entrypoint.sh
│   ├── install.sh
│   ├── journald.conf
│   ├── masked-units.list
│   ├── system.conf
│   └── test/
│       └── test.sh               # бывшее _shared/test/systemd/test.sh
├── texlive/
│   └── texlive-appimage.sh
└── README.md                     # этот файл
```

Принципы именования:

- Каждая фича – отдельная поддиректория с самодостаточным набором файлов.
- Файлы фичи НЕ ссылаются на соседние фичи (например, `systemd/install.sh`
  не должен `source ../base/vars.sh`). Общие функции живут в `base/` и
  подключаются явно через `source`.
- `test/` подсадки переезжают внутрь соответствующей фичи:
  `test/systemd/test.sh` → `systemd/test/test.sh`.
- Внутри `sources/<image>/_shared/` после копирования сохраняется та же
  структура, что и в исходном `_shared/`, чтобы пути внутри Dockerfile
  оставались стабильными.

### Расщепление `base/vars.sh`

Текущий `_shared/vars.sh` содержит одновременно:

- переменные окружения (`PYTHON_VERSION`, `PYENV_ROOT`) – нужны почти
  всем образам через `_shared/_all/build.sh:32-33`;
- функцию `checkout_upstream` – нужна только `omniroute` и `librechat`.

Если оставить их в одном файле, любая правка комментария в
`checkout_upstream` пересоберёт все 34 образа. Поэтому файл делится:

- `base/python-env.sh` – переменные;
- `base/git-helpers.sh` – функция `checkout_upstream`.

В `base/_all/build.sh` остаётся `source base/python-env.sh` (нужно всем).
В `sources/omniroute/vars.sh` и `sources/librechat/vars.sh` добавляется
явный `source _shared/base/git-helpers.sh`. Оба файла попадают в
`sources/<image>/_shared/` автоматически через `copy-shared.sh` (он
копирует весь `base/.`), так что источник доступен по относительному пути
из `vars.sh` образа.

---

## 5. Маппинг старое ↔ новое

| Было | Станет |
|---|---|
| `_shared/_all/build.sh` | `_shared/base/_all/build.sh` |
| `_shared/_all/matrix.sh` | `_shared/base/_all/matrix.sh` |
| `_shared/_all/push.sh` | `_shared/base/_all/push.sh` |
| `_shared/_all/vars.sh` | `_shared/base/_all/vars.sh` |
| `_shared/_all/appimage.sh` | `_shared/base/_all/appimage.sh` |
| `_shared/vars.sh` (переменные) | `_shared/base/python-env.sh` |
| `_shared/vars.sh` (`checkout_upstream`) | `_shared/base/git-helpers.sh` |
| `_shared/prepare2check.sh` | `_shared/base/prepare2check.sh` |
| `_shared/sudoers` | `_shared/base/sudoers` |
| `_shared/install/ansible/` | `_shared/ansible/` |
| `_shared/install/openwrt/` | `_shared/openwrt/` |
| `_shared/install/systemd2docker/` | `_shared/systemd/` |
| `_shared/test/systemd/` | `_shared/systemd/test/` |
| `_shared/install/coder.sh` | `_shared/coder/coder.sh` |
| `_shared/install/docker.sh` | `_shared/docker/docker.sh` |
| `_shared/install/profile.sh` | `_shared/profile/profile.sh` |
| `_shared/install/texlive-appimage.sh` | `_shared/texlive/texlive-appimage.sh` |

---

## 6. Контракт деклараций в `sources/<image>/vars.sh`

Каждый образ явно декларирует две переменные внутри блока `{ ... }`:

- `SHARED_FEATURES` – массив нужных фич из `_shared/` (без `base`).
- `USES_PODMAN_SH=1` – если образ копирует `podman.sh`.

### Канонический пример

`sources/ansible-ubuntu/vars.sh` после миграции:

```bash
#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='001'
  DEPENDS=''
  SHARED_FEATURES=('ansible')
  USES_PODMAN_SH=1
}
_shared/base/_all/copy-shared.sh "sources/${TAG}" "${SHARED_FEATURES[@]}"
/usr/bin/env cp -fv podman.sh "sources/${TAG}/_shared"
```

### Правила

- `SHARED_FEATURES` – **строго bash‑массив, однострочный**, объявленный
  внутри блока `{ ... }` одной строкой.
- Имена фич в **одинарных кавычках**, через пробел, без запятых.
- **Комментариев и других операторов в строке объявления быть не
  должно.** Это требование продиктовано парсингом через `sed` в
  детекторе (раздел 7) – детектор не использует `source`, чтобы
  избежать сайд‑эффектов.
- Допустимые имена: `[a-z0-9_-]+`. Многострочные объявления и
  `declare -a` **не поддерживаются**.
- `USES_PODMAN_SH=1` – булева декларация, либо `1` (копирует), либо
  отсутствует (не копирует).
- Если `SHARED_FEATURES` не задана – fallback: считается, что образ
  зависит от всего `_shared`. Сохраняет совместимость на время
  миграции.
- `base` подключается всегда (через `copy-shared.sh`), её в массиве
  указывать не нужно.

### Утилита `_shared/base/_all/copy-shared.sh`

```bash
#!/usr/bin/env bash
# Usage: copy-shared.sh <DEST_DIR> [<FEATURE>...]
# Copies _shared/base/ + each requested feature into <DEST_DIR>/_shared/
set -ueo pipefail
DEST="$1"; shift
SHARED_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "${DEST}/_shared"
/usr/bin/env cp -rf "${SHARED_ROOT}/base/." "${DEST}/_shared/"
for feat in "$@"; do
  [[ -d "${SHARED_ROOT}/${feat}" ]] || {
    echo "unknown feature: ${feat}" >&2; exit 66; }
  mkdir -p "${DEST}/_shared/${feat}"
  /usr/bin/env cp -rf "${SHARED_ROOT}/${feat}/." "${DEST}/_shared/${feat}/"
done
```

### Sanity‑check на рассинхон

В `copy-shared.sh` добавляется вторая проверка: если в `vars.sh` образа
есть `cp ... _shared/<feat>/...` без объявления `<feat>` в
`SHARED_FEATURES` – выводится warning на stderr. Это ловит момент, когда
разработчик добавил `cp` и забыл обновить декларацию. В отличие от
pre‑commit хука, проверка срабатывает на каждой сборке и в CI, и локально.
Sanity‑check живёт **в `copy-shared.sh`** (точка сборки), а не в
детекторе (точка формирования матрицы) – это разделение ответственности:
детектор только читает, копировщик валидирует.

---

## 7. Логика diff‑фильтрации в `_shared/base/_all/vars.sh`

Текущая реализация в `_shared/_all/vars.sh:47-50` заменяется на точечный
детектор. Принципиальное требование: **`sources/<image>/vars.sh` нельзя
`source` напрямую**, потому что эти файлы делают реальные `cp`/`mv`/`awk`
по файловой системе. Декларации читаются **статически через sed/grep**.

### Статический парсер `SHARED_FEATURES`

Регулярка рассчитана на строго однострочный формат (см. правила раздела 6):

```bash
feats_raw=$(/usr/bin/env sed -n \
  "s/^[[:space:]]*SHARED_FEATURES=(\\(.*\\))[[:space:]]*$/\\1/p" \
  "${dir}vars.sh")
# now feats_raw contains e.g. "'ansible' 'docker'"
# split by whitespace and strip quotes
feats=()
for tok in ${feats_raw}; do
  tok="${tok#[\'\"]}"
  tok="${tok%[\'\"]}"
  [[ -n "${tok}" ]] && feats+=("${tok}")
done
```

### Маппинг имён фич на старой структуре

Чтобы избежать рассинхрона при Фазе 2 (переезде `_shared/install/<feat>`
→ `_shared/<feat>`), декларации `SHARED_FEATURES` сразу используют
канонические имена без префикса `install/`. В детекторе Фазы 1 (пока
файлы лежат на старых местах) есть явный маппинг:

```bash
# Phase 1: detect against old layout
shared_root_subpath() {
  local feat="$1"
  case "${feat}" in
    ansible|openwrt|systemd|coder|docker|profile|texlive)
      echo "_shared/install/${feat}"
      ;;
    *)
      echo "_shared/${feat}"
      ;;
  esac
}
```

В Фазе 2 после переезда `_shared/install/<feat>` → `_shared/<feat>` этот
маппинг удаляется, а `SHARED_FEATURES` в образах **не меняются** –
декларации остаются каноническими на всём протяжении миграции.

### Полный скелет детектора

```bash
# Order of checks matters:
# 1. MANUAL_IMAGES_DIRS overrides everything.
# 2. GITHUB_EVENT_NAME=schedule (or CI_PIPELINE_SOURCE=schedule) → rebuild all.
# 3. Otherwise: diff-filter.

if [[ -n "${MANUAL_IMAGES_DIRS:-}" ]]; then
  # already handled above
  :
elif [[ "${GITHUB_EVENT_NAME:-${CI_PIPELINE_SOURCE:-}}" == 'schedule' ]]; then
  source_dirs='sources/*'
else
  shared_changes=$(/usr/bin/env printf '%s\n' "${diff}" |
    /usr/bin/env awk '/^_shared\// { print }')
  podman_changed=$(/usr/bin/env printf '%s\n' "${diff}" |
    /usr/bin/env awk '/^podman\.sh$/ { print }')
  if [[ -n "${shared_changes}" || -n "${podman_changed}" ]]; then
    extra_dirs=()
    for dir in sources/*/; do
      [[ -f "${dir}vars.sh" ]] || continue
      feats=()  # populated by sed parser above
      uses_podman=0
      /usr/bin/env grep -q \
        '^[[:space:]]*USES_PODMAN_SH=1[[:space:]]*$' "${dir}vars.sh" \
        && uses_podman=1
      if [[ ${#feats[@]} -eq 0 ]]; then
        # not migrated → assume full _shared dependency
        extra_dirs+=("${dir}")
      else
        deps=('_shared/base/')
        for feat in "${feats[@]}"; do
          deps+=("$(shared_root_subpath "${feat}")/")
        done
        for dep in "${deps[@]}"; do
          if /usr/bin/env printf '%s\n' "${shared_changes}" |
             /usr/bin/env grep -q "^${dep}"; then
            extra_dirs+=("${dir}")
            break
          fi
        done
      fi
      if [[ ${uses_podman} -eq 1 && -n "${podman_changed}" ]]; then
        extra_dirs+=("${dir}")
      fi
    done
    source_dirs=$(printf '%s\n' "${extra_dirs[@]}" |
                  /usr/bin/env sort -u)
  else
    source_dirs=$(/usr/bin/env printf '%s\n' "${diff}" |
      /usr/bin/env awk -F/ '/^sources\// { print $1 "/" $2 }' |
      /usr/bin/env sort -u)
  fi
fi
```

Особенности:

- `base` подключается неявно, поэтому `_shared/base/...` в diff пересоберёт
  все образы – это правильно, потому что там лежит каркас.
- Если `vars.sh` образа не задаёт `SHARED_FEATURES` – поведение безопасное
  по умолчанию: считается что зависит от всего.
- Сопоставление идёт по префиксу поддиректории: изменение
  `_shared/openwrt/install.sh` матчится только для образов с
  `SHARED_FEATURES=('openwrt' ...)`.
- `USES_PODMAN_SH=1` отслеживается через явную декларацию, не через grep
  `cp ... podman.sh`. Это явный контракт, легко читается и легко
  валидируется.

### Требования к окружению

- **bash 4.4+** – для корректного расширения пустого массива под `set -u`
  (`"${IMAGES_DIRS[@]}"` в `matrix.sh:9`). Ubuntu 24.04 ships bash 5.2,
  Ubuntu 22.04 – bash 5.1, оба подходят.
- `sed`, `grep`, `awk`, `sort`, `uniq` – стандартный GNU coreutils.

---

## 8. Адаптация `.github/workflows/containers.yaml`

Сейчас джоб `define-matrix` в `.github/workflows/containers.yaml:22-26`
вызывает `_shared/_all/matrix.sh`. После миграции путь меняется:

```yaml
- name: define matrix
  id: define-matrix
  run: |
    source _shared/base/_all/matrix.sh
    echo "images=${DIR_SON}" >> "${GITHUB_OUTPUT}"
```

`matrix.sh` использует тот же `vars.sh` и отдаёт уже отфильтрованный
`IMAGES_DIRS`. Если дифф пустой (например, изменение только в `README.md`)
– `IMAGES_DIRS` будет пустым, `DIR_SON='[]'`.

### Пропуск `containers` при пустой матрице

```yaml
containers:
  if: needs.define-matrix.outputs.images != '[]'
```

Сравнение со строкой `'[]'` корректно: `matrix.sh:8-13` формирует именно
строку `'[]'` при пустом `IMAGES_DIRS`. Под `set -u` цикл
`for dir in "${IMAGES_DIRS[@]}"` с пустым массивом работает на bash 4.4+
(см. требования к окружению в разделе 7).

### `all-green` при пустой матрице

`all-green` (`.github/workflows/containers.yaml:73-89`) при пустой матрице
получит `containers.result == 'skipped'`. По умолчанию GitHub Actions
считает `skipped` неудачей для зависимых джобов, поэтому
`wait-for-status-checks` без `if: always()` тоже завершится ошибкой.
Нужна явная страховка:

```yaml
all-green:
  if: always() && github.event_name == 'pull_request' &&
      (needs.containers.result == 'success' ||
       needs.containers.result == 'skipped') &&
      (needs.MegaLinter.result == 'success' ||
       needs.MegaLinter.result == 'skipped')
```

### Schedule‑режим

Для еженедельной пересборки (`.github/workflows/containers.yaml:9-10`)
всех образов детектор обходится через явную проверку. **Порядок важен**:

1. `MANUAL_IMAGES_DIRS` – обрабатывается первым, переопределяет всё.
   Без этого локальный запуск `build.sh` без `MANUAL_IMAGES_DIRS` попал бы
   в schedule‑ветку и пересобрал бы всё.
2. `GITHUB_EVENT_NAME=schedule` – собирает все образы.
3. Иначе – diff‑фильтр.

Сравнение делается через `[[ ]]`, а не `case`, чтобы избежать
неоднозначностей с пустой строкой:

```bash
if [[ -n "${MANUAL_IMAGES_DIRS:-}" ]]; then
  # already handled above
  :
elif [[ "${GITHUB_EVENT_NAME:-${CI_PIPELINE_SOURCE:-}}" == 'schedule' ]]; then
  source_dirs='sources/*'
  IMAGES_DIRS=()
  for IMAGE_DIR in ${source_dirs}; do
    [[ -d "${IMAGE_DIR}" ]] && IMAGES_DIRS+=("${IMAGE_DIR}")
  done
  return 0 2>/dev/null || exit 0
else
  # diff-filter logic from section 7
  ...
fi
```

`return 0 2>/dev/null || exit 0` работает в обоих режимах: `return` –
если файл source'ится (через `matrix.sh`), `exit` – если запущен напрямую.
Этот блок ставится **в самый конец** выполнения `vars.sh`, после
формирования `IMAGES_DIRS`, чтобы не пропустить другие шаги.

---

## 9. План миграции по фазам

Каждая фаза – отдельный merge request в `master`. Между фазами CI
остаётся рабочим.

**Принцип упорядочивания:** сначала внедряется детектор (Фаза 1) на
текущей структуре `_shared` и **сразу задаются `SHARED_FEATURES` всем
34 образам** (даже тем, кто продолжит делать полный `cp -rf _shared`
до Фазы 4). Это даёт точную работу детектора с первого коммита. Без
этого немигрированные образы на fallback'е съедят всю экономию Фазы 1.

### Фаза 1. Детектор `SHARED_FEATURES` + `USES_PODMAN_SH` на текущей структуре

1. Не двигая файлы, добавить в `_shared/_all/vars.sh` точечный детектор
   из раздела 7 (с маппингом `shared_root_subpath` для старой структуры).
2. Добавить обработку `podman.sh` в diff‑фильтр.
3. **Прописать `SHARED_FEATURES` и `USES_PODMAN_SH` во всех 34 образах**
   одновременно. Для полных потребителей `SHARED_FEATURES` дублирует
   текущее поведение (зависит от всего `_shared/` через полный `cp`),
   но с явной декларацией для детектора. Полный список – в разделе 10.
4. Поправить `_shared/_all/vars.sh:42-44` – убрать fallback `find sources/*`
   на пустой diff, заменить на `IMAGES_DIRS=()` + `return`.
5. Поправить `_shared/_all/vars.sh:25-28` – для GitHub Actions
   `diff_source`/`diff_target` использовать `github.event.before`/`after`,
   не `remotes/origin/master`/`.` (последнее всегда даёт пустой diff).

После Фазы 1 изменение `_shared/install/openwrt/install.sh` триггерит
ровно 3 openwrt‑образа. Изменение `podman.sh` триггерит ровно 6 образов.
Изменение `_shared/install/ansible/...` триггерит `ansible-06..11`,
`ansible-ubuntu`, `ansible-builder`, `ansible-appimage`,
`docker-ansible-06..11`.

**Commit 1.** Точечный детектор и полная декларация `SHARED_FEATURES`.

### Фаза 2. Утилита `copy-shared.sh` и новые пути

1. Создать структуру `_shared/<feature>/` рядом с существующими файлами
   (`ansible/`, `openwrt/`, `systemd/`, `coder/`, `docker/`, `profile/`,
   `texlive/`). Использовать `git mv`.
2. Добавить `_shared/base/_all/copy-shared.sh` **только с новыми путями**
   – никакого дублирования `install/<feat>/` внутри копии, иначе контекст
   сборки временно удваивается.
3. Удалить маппинг `shared_root_subpath` из детектора – теперь декларации
   `SHARED_FEATURES` напрямую матчатся с `_shared/<feat>/`.
4. Перевести на `copy-shared.sh` точечных потребителей (owrt‑*, omniroute,
   librechat, builder‑kitty, mkosi, opencode, systemd‑debian12,
   systemd‑debian13). Их `vars.sh` теперь зовёт `copy-shared.sh` вместо
   ручного `cp -rf`.
5. В Dockerfile'ах `systemd-debian12`, `systemd-debian13` поправить
   пути: `/files/shared/install/systemd2docker/...` →
   `/files/shared/systemd/...`.
6. Поднять `IMAGE_VER` в `sources/systemd-debian12/vars.sh` и
   `sources/systemd-debian13/vars.sh` – чтобы пользователи, привязанные
   к тегу, увидели breaking change (см. раздел 11).

**Внимание:** Фаза 2 атомарна в рамках одного коммита. На полпути между
переездом файлов и переключением `vars.sh` детектор сломается.

**Commit 2.** `copy-shared.sh` + миграция точечных потребителей.

### Фаза 3. Миграция группы systemd

1. Перевести на точечное копирование:
   - `systemd-ubuntu-22_04`, `docker-ubuntu-22_04`,
     `victim-ubuntu-22_04` → уже имеют `SHARED_FEATURES=('systemd')` с
     Фазы 1, теперь убирают полный `cp -rf _shared`.
2. Поднять `IMAGE_VER` в этих трёх образах.

**Commit 3.** Миграция systemd‑образов.

### Фаза 4. Миграция группы ansible

1. `ansible-06..11` – убирают полный `cp -rf _shared` (у них уже
   `SHARED_FEATURES=('ansible')` с Фазы 1).
2. `ansible-ubuntu`, `ansible-builder`, `ansible-appimage` – то же.
3. `docker-ansible-06..11` – `SHARED_FEATURES=('ansible' 'docker')` с
   Фазы 1, убирают полный `cp -rf _shared`.
4. Поднять `IMAGE_VER` во всех затронутых образах.

**Commit 4.** Миграция ansible‑образов.

### Фаза 5. Миграция остальных

1. `linters-ubuntu-22_04` → `SHARED_FEATURES=()` с Фазы 1. Убирает
   полный `cp -rf _shared`. В Dockerfile остаётся
   `COPY _shared/prepare2check.sh /` – после переезда файла в Фазе 6
   путь в Dockerfile нужно поправить на `_shared/base/prepare2check.sh`.
2. `utils-ubuntu-22_04`, `vibeco-ubuntu-24_04` →
   `SHARED_FEATURES=('coder' 'profile')` с Фазы 1.
3. `texlive-myminimal` → `SHARED_FEATURES=('texlive')` с Фазы 1.
4. Поднять `IMAGE_VER` во всех затронутых образах.

**Commit 5.** Миграция оставшихся образов.

### Фаза 6. Расщепление `base/vars.sh` и финальная зачистка

1. Разделить `_shared/base/vars.sh` на `python-env.sh` и `git-helpers.sh`
   (см. раздел 4).
2. В `sources/omniroute/vars.sh` и `sources/librechat/vars.sh` добавить
   явный `source _shared/base/git-helpers.sh`.
3. Поправить `_shared/base/_all/build.sh:9` – он source'ил `_shared/vars.sh`,
   теперь нужно `source _shared/base/python-env.sh`.
4. Удалить старые пути: `_shared/install/`, `_shared/test/`,
   `_shared/_all/`, `_shared/vars.sh`, `_shared/prepare2check.sh`,
   `_shared/sudoers`. Перед удалением проверить отсутствие ссылок:
   ```bash
   /usr/bin/env grep -rn -E '_shared/(install/|test/|_all/[^b]|vars\.sh$)' \
     --include='*.sh' --include='Dockerfile*' --include='*.yaml' .
   ```
   Регулярка `_all/[^b]` исключает совпадения с `_shared/base/_all/`.
5. Поправить путь к `matrix.sh` в `.github/workflows/containers.yaml`:
   `_shared/_all/matrix.sh` → `_shared/base/_all/matrix.sh`.
6. Добавить `if: needs.define-matrix.outputs.images != '[]'` к джобу
   `containers` и `if: always() && ...` к `all-green`.
7. В Dockerfile `linters-ubuntu-22_04` поправить
   `_shared/prepare2check.sh` → `_shared/base/prepare2check.sh`.

**Commit 6.** Расщепление `base/vars.sh` и финальная зачистка.

---

## 10. Сводная таблица `SHARED_FEATURES` (вводится в Фазе 1)

```text
ansible-06..11                     → ('ansible',)              USES_PODMAN_SH=0
ansible-appimage                   → ('ansible',)              USES_PODMAN_SH=0
ansible-builder                    → ('ansible',)              USES_PODMAN_SH=1
ansible-ubuntu                     → ('ansible',)              USES_PODMAN_SH=1
builder-kitty                      → ()                        USES_PODMAN_SH=0
docker-ansible-06..11              → ('ansible', 'docker')     USES_PODMAN_SH=0
docker-ubuntu-22_04                → ('systemd',)              USES_PODMAN_SH=0
librechat                          → ()                        USES_PODMAN_SH=0
linters-ubuntu-22_04               → ()                        USES_PODMAN_SH=0
mkosi-26_0-ubuntu-24_04            → ()                        USES_PODMAN_SH=0
omniroute                          → ()                        USES_PODMAN_SH=0
opencode-ubuntu-22_04              → ()                        USES_PODMAN_SH=0
owrt-mtk-filogic-24_10_1           → ('openwrt',)              USES_PODMAN_SH=0
owrt-rock-armv8-24_10_1            → ('openwrt',)              USES_PODMAN_SH=0
owrt-sxi-cora53-24_10_1            → ('openwrt',)              USES_PODMAN_SH=0
podman-ubuntu-22_04                → ()                        USES_PODMAN_SH=1
podman-ubuntu-24_04                → ()                        USES_PODMAN_SH=1
systemd-debian12                   → ('systemd',)              USES_PODMAN_SH=0
systemd-debian13                   → ('systemd',)              USES_PODMAN_SH=0
systemd-ubuntu-22_04               → ('systemd',)              USES_PODMAN_SH=0
texlive-myminimal                  → ('texlive',)              USES_PODMAN_SH=0
utils-ubuntu-22_04                 → ('coder', 'profile')      USES_PODMAN_SH=0
vibeco-ubuntu-24_04                → ('coder', 'profile')      USES_PODMAN_SH=1
victim-ubuntu-22_04                → ('systemd',)              USES_PODMAN_SH=0
```

`omniroute` и `librechat` декларируют `SHARED_FEATURES=()`, но
дополнительно `source _shared/base/git-helpers.sh` для `checkout_upstream`.
Эта зависимость покрывается неявным включением `base` – `copy-shared.sh`
копирует весь `base/.` (включая `git-helpers.sh`) в `sources/<image>/_shared/`,
поэтому `source _shared/base/git-helpers.sh` доступен из `vars.sh` образа
по относительному пути. Правка `base/git-helpers.sh` пересоберёт все
образы (т.к. `base/` подключается всем) – это сознательное ограничение,
не требующее отдельной фазы оптимизации.

---

## 11. Изменение Dockerfile'ов

Большинство Dockerfile'ов используют `COPY _shared /files/shared` или
`COPY _shared /files`. После миграции это продолжает работать – меняется
только внутреннее содержимое `_shared`, а не её верхнеуровневая позиция
в контексте сборки.

Требующие внимания места:

- `sources/systemd-debian12/Dockerfile:6`, `:13` жёстко ссылаются на
  `/files/shared/install/systemd2docker/...`. После миграции путь
  становится `/files/shared/systemd/...`. Аналогично для
  `systemd-debian13`. Меняется в Фазе 2.
- `sources/linters-ubuntu-22_04/Dockerfile:10` –
  `_shared/prepare2check.sh` переедет в `_shared/base/prepare2check.sh`.
  Меняется в Фазе 6.
- `sources/vibeco-ubuntu-24_04/Dockerfile:14` ссылается на
  `/files/shared/install/coder.sh` – после миграции путь станет
  `/files/shared/coder/coder.sh`. Меняется в Фазе 5.

### Breaking change и версионирование

Контейнеры пушатся в `ghcr.io` с тегами `:latest`/`:date`/`:version`
(`_shared/_all/build.sh:37-40`). Изменение путей внутри образов – breaking
change для тех, кто заходит в контейнер через `podman exec` и ожидает
`/files/shared/install/...`. В каждой фазе, меняющей пути, **поднимать
`IMAGE_VER`** во всех затронутых образах, чтобы можно было отличить
«до миграции» от «после» по тегу.

---

## 12. Риски и смягчения

- **Забыли обновить `SHARED_FEATURES` / `USES_PODMAN_SH`** при добавлении
  нового `cp ... _shared/<feat>/...` – образ не пересоберётся при
  изменении забытой фичи. Смягчение: sanity‑check в `copy-shared.sh`
  (раздел 6), выводит warning при рассинхроне.

- **`set -u` падает на необъявленной `SHARED_FEATURES`** – статическое
  чтение через `sed` (раздел 7) не использует `source`, поэтому `set -u`
  не влияет на детектор. В самих `vars.sh` образцов массив объявляется
  всегда (после Фазы 1).

- **Рассинхрон с GitLab CI** – в репо `.gitlab-ci.yml` отсутствует.
  Проверка `CI_PIPELINE_SOURCE` сохранена для совместимости, может быть
  удалена в Фазе 6 если GitLab возвращать не планируется.

- **`base/` пересобирает всё** – любая правка `base/...` триггерит 34
  образа. Смягчение: расщепление `base/vars.sh` на `python-env.sh` и
  `git-helpers.sh` (Фаза 6) изолирует изменения. Дальнейшее расщепление
  `base/_all/build.sh` от `base/_all/matrix.sh` возможно, но не
  требуется – правки `build.sh` и так редки.

- **Атомарность Фазы 2** – в одном коммите нужно переехать
  `_shared/install/<feat>` → `_shared/<feat>`, убрать маппинг в детекторе
  и переключить точечные образы на `copy-shared.sh`. На полпути детектор
  сломается. Смягчение: коммитить в одной транзакции, прогнать локально
  перед push.

- **Remote build cache** – если детектор работает точно, кеш перестаёт
  быть нужен для оптимизации матрицы. Cache остаётся полезен для
  schedule‑сборок (раз в неделю всё пересобирается) и как страховка.

---

## 13. Приёмка

После завершения всех фаз должны выполняться:

1. Локальная сборка любого образа через
   `MANUAL_IMAGES_DIRS='<image>/' _shared/base/_all/build.sh`
   отрабатывает без ошибок.
2. Изменение только в `_shared/openwrt/install.sh` триггерит в CI ровно
   3 образа: `owrt-mtk-filogic-24_10_1`, `owrt-rock-armv8-24_10_1`,
   `owrt-sxi-cora53-24_10_1`.
3. Изменение только в `_shared/coder/coder.sh` триггерит ровно
   `utils-ubuntu-22_04` и `vibeco-ubuntu-24_04`.
4. Изменение только в `_shared/base/_all/vars.sh` триггерит все 34
   образа – потому что `base/` подключается неявно всем.
5. Изменение только в `_shared/base/git-helpers.sh` триггерит все 34
   образа – по той же причине. Это сознательное ограничение, отдельной
   фазы оптимизации не запланировано.
6. Изменение только в `podman.sh` триггерит ровно 6 образов:
   `ansible-appimage`, `ansible-builder`, `ansible-ubuntu`,
   `podman-ubuntu-22_04`, `podman-ubuntu-24_04`, `vibeco-ubuntu-24_04`.
7. Изменение только в `README.md` не триггерит ни одного образа, джоб
   `containers` пропускается, `all-green` проходит через
   `if: always() && ...`.
8. schedule‑сборка раз в неделю собирает все 34 образа без исключения.
9. Локальный запуск `build.sh` без `MANUAL_IMAGES_DIRS` НЕ пересобирает
   всё автоматически – выводит пустой список образов и завершается.

---

## 14. Ссылки по коду

- Текущий pipeline: `.github/workflows/containers.yaml:1-89`
- Текущая фильтрация diff: `_shared/_all/vars.sh:36-70`
- Fallback на полный пересбор:
  - `_shared/_all/vars.sh:42-44` (пустой diff → `find sources/*`)
  - `_shared/_all/vars.sh:47-50` (правка `_shared/` → `source_dirs='sources/*'`)
- Слепое пятно для `podman.sh`: `_shared/_all/vars.sh:39`
  (`egrep '^(_shared/)|(sources/)'` не ловит корневые файлы)
- Формирование матрицы: `_shared/_all/matrix.sh:7-13`
- Использование `podman.sh` в образах:
  - `sources/ansible-appimage/vars.sh:7` (закомментировано – игнорировать)
  - `sources/ansible-builder/vars.sh:7`
  - `sources/ansible-ubuntu/vars.sh:7`
  - `sources/podman-ubuntu-22_04/vars.sh:4`
  - `sources/podman-ubuntu-24_04/vars.sh:4`
  - `sources/vibeco-ubuntu-24_04/vars.sh:6`
- Список игнорируемых артефактов: `.gitignore`
- Универсальный копировщик (после миграции):
  `_shared/base/_all/copy-shared.sh`
