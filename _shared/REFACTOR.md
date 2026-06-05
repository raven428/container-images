# Рефакторинг: декларативные `SHARED_ASSETS` в `vars.sh`

Документ описывает план миграции на манифестно‑декларативную модель зависимостей образов от общих ассетов. Предназначен для исполнения младшими разработчиками. Изменения распределяются на несколько PR в указанном порядке, но допустимо объединять, если объём и риски контролируемые.

## Цель

Сейчас при изменении любого файла в `_shared/` пайплайн `.github/workflows/containers.yaml` ребилдит все контейнеры из `sources/`. Логика в `_shared/_all/vars.sh:47-50` принимает решение «есть правка вне `sources/` ⇒ собрать всё». Это грубо: правка в `_shared/install/openwrt/` не должна затрагивать `systemd-debian12`, и наоборот.

Нужно сделать так, чтобы пересобирались только те образы, которые реально используют изменившиеся файлы. Для этого вводится явный манифест зависимостей в каждом `sources/<image>/vars.sh`.

## Текущее устройство (короткая справка)

- `containers.yaml` запускает job `define-matrix`, тот источает `_shared/_all/matrix.sh`, который читает массив `IMAGES_DIRS` из `_shared/_all/vars.sh`.
- `_shared/_all/vars.sh` смотрит diff между `origin/master` и `HEAD`, фильтрует пути `_shared/|sources/`. Если в diff есть что‑то вне `sources/` — `source_dirs='sources/*'` (все образы). Иначе — только те `sources/<image>/`, где есть прямые правки.
- Для каждого матричного образа `_shared/_all/build.sh` подключает `sources/${TAG}/vars.sh`, который сам делает `cp -rf _shared "sources/${TAG}"` и точечные `cp` нужных файлов. Это и источник истины, и побочный эффект сборки одновременно.
- `sources/*/_shared` игнорируется в `.gitignore`.

## Новая модель

### Манифест в `vars.sh`

Каждый `sources/<image>/vars.sh` объявляет массив строк `SHARED_ASSETS`. Запись имеет формат:

```
src[:dst]
```

Семантика:
- `src` — путь относительно корня репозитория. Может указывать на `_shared/...`, `podman.sh`, `sources/<другой-image>/...` — на что угодно
- `dst` — целевой путь внутри `sources/<image>/`. Если опущен:
  - для `src`, начинающегося с `_shared/`, ставится тот же относительный путь (то есть будет `sources/<image>/_shared/...`)
  - для прочих — корень контекста образа с сохранением `basename(src)`
- `src`, оканчивающийся на `/`, копируется рекурсивно как директория
- `src`, содержащий `*`, разворачивается как glob под `shopt -s nullglob globstar`
- если `src` не существует — `stage_shared_assets` падает с явной ошибкой

### Строгая конвенция порядка в `vars.sh`

Файл `sources/<image>/vars.sh` пишется в фиксированном порядке:

1. Шапка: `IMAGE_VER`, `IMAGE_TEST`, `DEPENDS`, `SHARED_ASSETS` (любые из них опциональны, кроме `IMAGE_VER`)
2. Вызов `stage_shared_assets` (без аргументов; функция читает `${TAG}` и `${SHARED_ASSETS[@]}` из окружения)
3. Постпроцессы: `awk`/`sed`/`cp`/`mv` поверх отстейдженного контекста (например, правки `async-check.diff` в текущих `ansible-06..11`)

До объявления `SHARED_ASSETS` в файле запрещены любые команды с побочными эффектами: `cp`, `mv`, `rm`, `mkdir`, `install`, `awk`, `sed`, `cat`, `tee`, `printf` с редиректом в файл, `>`/`>>` редиректы, вызовы внешних бинарников через `/usr/bin/env ...`. Это требование matrix‑скрипта, который читает `vars.sh` в подоболочке для извлечения массива.

### Staging‑функция

Живёт в `_shared/vars.sh` (этот файл уже подключается из `_shared/_all/build.sh:9`). Добавляются:

- `stage_shared_assets` — выполняет копирование. Алгоритм:
  1. Проверяет, что `${TAG}` определён
  2. Если в `SHARED_ASSETS` встречается ассет с `dst`, попадающий в `sources/${TAG}/_shared/...`, перед копированием удаляет `sources/${TAG}/_shared` (один раз)
  3. Идёт по `SHARED_ASSETS`, для каждой записи:
     - парсит `src:dst` через `IFS=:`
     - определяет дефолтный `dst`, если не задан
     - разворачивает glob/директорию через `_expand_asset_src` для проверки существования
     - копирует: директории через `cp -rf`, файлы через `cp -f`, glob — поэлементно
  4. Падает с понятной ошибкой при отсутствии источника
- `_expand_asset_src "<src>"` — печатает на stdout по строке абсолютные/относительные пути, на которые разворачивается `src`. Используется и matrix‑скриптом.

### matrix‑скрипт (`_shared/_all/vars.sh`)

Логика выбора `IMAGES_DIRS`:

1. Считается diff: `git diff --name-only "${diff_source}" "${diff_target}"`. Никакого `egrep` фильтра по префиксам быть не должно — мы теперь матчим к произвольным путям из манифестов
2. Поддерживается локальный режим тестирования: переменная окружения `MANUAL_DIFF` (multiline или пробел‑разделённая) подменяет вычисленный diff — для синтетических прогонов
3. Спец‑ветки rebuild all (`source_dirs='sources/*'`, переход к существующему циклу заполнения `IMAGES_DIRS`):
   - `${GITHUB_EVENT_NAME:-}` == `schedule`
   - в diff есть что‑либо под `_shared/_all/` или сам `_shared/vars.sh` (это правки фреймворка и staging‑слоя)
4. Иначе:
   - объявить set `picked` (ассоциативный массив)
   - прямые попадания: для каждой строки diff, начинающейся с `sources/<dir>/`, добавить `sources/<dir>/` в `picked`
   - для каждого `sources/<image>/vars.sh`, где `<image>` ещё не в `picked`:
     - запустить подоболочку:
       ```bash
       ( set +u
         TAG='<image>'
         SHARED_ASSETS=()
         stage_shared_assets() { :; }
         source "sources/${TAG}/vars.sh" >/dev/null 2>&1 || true
         printf '%s\n' "${SHARED_ASSETS[@]:-}"
       )
       ```
       Шунтировать `cp`/`mv`/`rm`/`awk`/`sed` не нужно: конвенция запрещает их до `SHARED_ASSETS`, а после массива они уже не повлияют на извлечение. Шунт `stage_shared_assets` нужен, чтобы не было реального копирования. Если по какой‑то причине `vars.sh` всё же сделает что‑то побочное — это словит линтер
     - распарсить каждую запись, извлечь `src`
     - развернуть `src` через `_expand_asset_src` в список конкретных путей рабочего дерева
     - матч к diff: образ задет, если для хотя бы одной записи манифеста выполняется условие
       - точное равенство пути из diff с развёрнутым путём из манифеста, **или**
       - запись манифеста — директория (заканчивается на `/` или `src` указывает на каталог), и путь из diff лежит внутри неё (`diff_path == src` или `diff_path` начинается с `src/`)
     - при совпадении — `picked["sources/${image}/"]=1`, break по записям
   - после обхода всех образов: `IMAGES_DIRS=( "${!picked[@]}" )`
5. Существующий рекурсивный `DEPENDS` в `_shared/_all/build.sh:22-26` отрабатывает дальше без изменений

### `_shared/_all/build.sh`

Не меняется. Функцию `stage_shared_assets` вызывает сам `vars.sh` каждого образа.

### `.github/workflows/containers.yaml`

Не меняется.

### `_shared/_all/matrix.sh`

Не меняется по существу — он по‑прежнему собирает `DIR_SON` из `IMAGES_DIRS`.

## Поведение по сценариям

- diff = `_shared/install/openwrt/*` ⇒ `owrt-mtk-filogic-24_10_1`, `owrt-rock-armv8-24_10_1`, `owrt-sxi-cora53-24_10_1`
- diff = `_shared/install/ansible/Dockerfile` ⇒ `ansible-06..11` плюс все, у кого в манифесте есть `_shared/install/ansible/` (если такие будут добавлены)
- diff = `_shared/test/systemd/test.sh` ⇒ `systemd-debian12`, `systemd-debian13`, `systemd-ubuntu-22_04`
- diff = `podman.sh` ⇒ `podman-ubuntu-22_04`, `podman-ubuntu-24_04`, `ansible-ubuntu`, `ansible-builder`, `vibeco-ubuntu-24_04`
- diff = `sources/librechat/patches/x` ⇒ только `librechat`
- diff = `sources/ansible-ubuntu/files/install.sh` ⇒ `ansible-ubuntu` (прямое) плюс `ansible-builder` и `ansible-appimage` (через манифест)
- diff = `_shared/_all/build.sh` ⇒ все образы
- diff = `_shared/vars.sh` ⇒ все образы
- event = `schedule` ⇒ все образы

## План работ

PR можно дробить, но порядок зависит:

### PR1 — фреймворк staging

1. Расширить `_shared/vars.sh`:
   - добавить `_expand_asset_src`
   - добавить `stage_shared_assets`
   - не ломать существующие `checkout_upstream`, `PYTHON_VERSION`, `PYENV_ROOT`
2. Покрыть локальным smoke‑тестом: вызов `stage_shared_assets` для синтетического `${TAG}` и `SHARED_ASSETS`
3. `_shared/_all/build.sh` и matrix‑скрипты пока не трогаем

Ожидаемый результат: новые функции существуют, никто их не использует, поведение пайплайна не изменилось.

### PR2 — миграция `vars.sh` (35 файлов)

Сразу с точными манифестами, без промежуточной фазы «все берут `_shared/` целиком». Для каждого образа:

1. Открыть `Dockerfile` (если есть)
2. Найти все `COPY` источники из контекста сборки и все ссылки на пути под `/files/shared/...`, `/files/...`
3. Перевести это в `SHARED_ASSETS`. По возможности использовать конкретные подпути, а не `_shared/` целиком
4. Сохранить `IMAGE_VER`, `IMAGE_TEST`, `DEPENDS`
5. Добавить вызов `stage_shared_assets` после декларации
6. Перенести постпроцессы после вызова `stage_shared_assets`
7. Удалить старые `cp -rf _shared`, точечные `cp _shared/install/...` и копии `podman.sh`

Поэлементно:

#### Группа openwrt

`sources/owrt-mtk-filogic-24_10_1/vars.sh`, `sources/owrt-rock-armv8-24_10_1/vars.sh`, `sources/owrt-sxi-cora53-24_10_1/vars.sh`:

```bash
#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='000'
SHARED_ASSETS=(
  '_shared/install/openwrt/:files/openwrt'
)
stage_shared_assets
```

#### Группа podman

`sources/podman-ubuntu-22_04/vars.sh`, `sources/podman-ubuntu-24_04/vars.sh`:

```bash
#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='000'
SHARED_ASSETS=(
  'podman.sh:podman.sh'
)
stage_shared_assets
```

#### Группа systemd

`sources/systemd-debian12/vars.sh`, `sources/systemd-debian13/vars.sh`:

```bash
#!/usr/bin/env bash
set -ueo pipefail
export IMAGE_VER='000'
export IMAGE_TEST='../../_shared/test/systemd/test.sh'
SHARED_ASSETS=(
  '_shared/install/systemd2docker/:_shared/install/systemd2docker'
  '_shared/test/systemd/test.sh:_shared/test/systemd/test.sh'
  # дополнительные пути _shared, реально используемые Dockerfile-ом — определить чтением Dockerfile
)
stage_shared_assets
```

`sources/systemd-ubuntu-22_04/vars.sh` — аналогично, с поправкой на собственный `Dockerfile`.

#### Группа ansible‑NN

`sources/ansible-06/vars.sh` (остальные 07..11 — по аналогии):

```bash
#!/usr/bin/env bash
set -ueo pipefail
# shellcheck disable=2034
{
  IMAGE_VER='001'
  DEPENDS='ansible-ubuntu/ ansible-builder/'
}
SHARED_ASSETS=(
  '_shared/install/ansible/Dockerfile:Dockerfile'
  '_shared/install/ansible/*:files/'
  # точечные пути _shared, нужные итоговому Dockerfile-у (определить чтением)
)
stage_shared_assets
# постпроцесс async-check.diff остаётся ниже, как раньше
/usr/bin/env cat "sources/${TAG}/files/async-check.diff" |
  /usr/bin/env awk \
    '/^--- .+site-packages\/ansible\/plugins\/action\/__init__/ { exit } { print }' |
  /usr/bin/env sed -rz \
    's/\x0d\x0a/\x0a/g; s/\x0d/\x0a/g; s/[ \t]+\x0a/\x0a/g; s/\x0a*$/\x0a/g' \
    >"sources/${TAG}/files/async-check-new.diff"
/usr/bin/env mv -fv "sources/${TAG}/files/async-check-new.diff" \
  "sources/${TAG}/files/async-check.diff"
```

#### Группа docker‑ansible‑NN

Для каждого посмотреть текущий `Dockerfile` и `vars.sh`, выписать минимум. Шаблон аналогичен ansible‑NN, но без правки `async-check.diff`.

#### `ansible-ubuntu`, `ansible-builder`, `ansible-appimage`

`sources/ansible-ubuntu/vars.sh`:

```bash
SHARED_ASSETS=(
  '_shared/:_shared'                # точечно сузить после прочтения Dockerfile
  'podman.sh:_shared/podman.sh'
)
stage_shared_assets
```

`sources/ansible-builder/vars.sh`:

```bash
SHARED_ASSETS=(
  '_shared/:_shared'                # сузить
  'podman.sh:_shared/podman.sh'
  'sources/ansible-ubuntu/files/install.sh:_shared/install.sh'
)
stage_shared_assets
```

`sources/ansible-appimage/vars.sh`:

```bash
SHARED_ASSETS=(
  '_shared/:_shared'                # сузить
  'sources/ansible-ubuntu/files/install.sh:_shared/install.sh'
)
stage_shared_assets
```

#### Группы utils/vibeco/victim/texlive/linters/docker‑ubuntu

Для каждого — индивидуально по Dockerfile. Шаблон:

```bash
SHARED_ASSETS=(
  '_shared/install/profile.sh:_shared/profile-dmisu'
  # плюс конкретные пути _shared, используемые Dockerfile-ом
)
stage_shared_assets
```

#### librechat

```bash
SHARED_ASSETS=()
stage_shared_assets
```

(вызов — no‑op; оставляем для единообразия)

#### mkosi‑26_0‑ubuntu‑24_04

Текущий `vars.sh` объявляет только `IMAGE_VER`. Если ассеты действительно не нужны:

```bash
SHARED_ASSETS=()
stage_shared_assets
```

#### opencode‑ubuntu‑22_04

Текущая структура каталога не содержит `vars.sh`. Проверить, что образ собирается, и при необходимости добавить `vars.sh` с пустым `SHARED_ASSETS`.

### PR3 — переключение matrix‑логики

1. Переписать `_shared/_all/vars.sh` по спецификации выше
2. Добавить поддержку `MANUAL_DIFF`
3. Сохранить совместимость с `MANUAL_IMAGES_DIRS` (он по‑прежнему имеет приоритет)
4. Прогнать набор синтетических тестов из раздела «Проверка» ниже

### PR4 — линтер‑правило

1. Добавить shell‑скрипт `_shared/_all/lint-vars.sh`, который проверяет, что в каждом `sources/*/vars.sh`:
   - есть строка с `SHARED_ASSETS=(`
   - до этой строки нет команд с побочными эффектами (regex по списку запрещённых ключевых слов и редиректам)
   - после `SHARED_ASSETS=...)` есть вызов `stage_shared_assets`
2. Подключить вызов скрипта в `.megalinter.yml` (через `EXTRA_RULES` или отдельный `CUSTOM_LINTER`) либо как отдельный job в `containers.yaml`

## Проверка

Чек‑лист до мержа PR2 и PR3:

1. Для каждого `sources/<image>/`:
   - сделать бэкап исходного содержимого: `cp -r sources/<image> /tmp/baseline-<image>`
   - применить новый `vars.sh`: `MANUAL_IMAGES_DIRS=<image>/ ./_shared/_all/build.sh` (или хотя бы вручную выполнить часть staging)
   - сравнить: `diff -r /tmp/baseline-<image> sources/<image>` — должно быть пусто (или различия только в ожидаемых местах)
2. Синтетические matrix‑прогоны с `MANUAL_DIFF`:
   - `MANUAL_DIFF='_shared/install/openwrt/Dockerfile'` ⇒ только `owrt-*`
   - `MANUAL_DIFF='_shared/install/ansible/Dockerfile'` ⇒ `ansible-06..11` (и возможно потребители, явно их указавшие)
   - `MANUAL_DIFF='_shared/test/systemd/test.sh'` ⇒ `systemd-*`
   - `MANUAL_DIFF='podman.sh'` ⇒ `podman-*`, `ansible-ubuntu`, `ansible-builder`, `vibeco-ubuntu-24_04`
   - `MANUAL_DIFF='sources/librechat/patches/x'` ⇒ только `librechat`
   - `MANUAL_DIFF='sources/ansible-ubuntu/files/install.sh'` ⇒ `ansible-ubuntu`, `ansible-builder`, `ansible-appimage`
   - `MANUAL_DIFF='_shared/_all/build.sh'` ⇒ rebuild all
   - `MANUAL_DIFF='_shared/vars.sh'` ⇒ rebuild all
3. Реальная сборка всех 35 образов локально: `MANUAL_IMAGES_DIRS='<image>/' ./_shared/_all/build.sh` для каждого. Все должны пройти
4. `shellcheck` чисто на всех изменённых скриптах
5. MegaLinter чисто
6. На тестовом PR проверить, что `define-matrix` отдаёт только ожидаемые образы; на cron‑прогоне — все

## Граничные случаи и риски

- Glob‑раскрытие должно быть детерминированным в matrix‑скрипте и в `stage_shared_assets`. Решается общей функцией `_expand_asset_src` и единым `shopt`
- Если кто‑то объявит `src`, не существующий в рабочем дереве, `stage_shared_assets` падает. Это намеренно — лучше явная ошибка, чем тихий пропуск
- При сравнении путей diff с записями манифеста нужно нормализовать оба источника: убирать ведущие `./`, схлопывать дублирующиеся `/`
- `_shared/_all/*` и `_shared/vars.sh` — это сам фреймворк. Их правки приводят к rebuild all жёстко, без анализа манифестов
- При расширении набора общих ассетов в будущем достаточно добавить файл в `_shared/`, отразить его в `SHARED_ASSETS` нужных образов и больше ничего — matrix сам разберётся
- Конвенция «никаких побочных эффектов до `SHARED_ASSETS`» обязательна. Линтер должен это ловить. Если линтер не запущен, единственное место, где можно случайно сломать matrix — это побочные эффекты в `vars.sh` до объявления массива. Это явно описано в комментарии в начале каждого `vars.sh` и в этом документе

## Объём

- 2 функции в `_shared/vars.sh`
- 1 переписанный `_shared/_all/vars.sh`
- 35 переписанных `sources/*/vars.sh` (из них ~20 требуют чтения Dockerfile для сужения)
- 1 линтер‑скрипт и подключение в megalinter
- Прогоны и тесты

## Что НЕ делаем в этом рефакторинге

- Не вводим контентные хэши образов и проверку существующих тегов в ghcr.io (отдельная будущая итерация)
- Не меняем `containers.yaml`
- Не меняем механизм `DEPENDS` в `_shared/_all/build.sh`
- Не переезжаем на `dorny/paths-filter` или другие GH‑Actions‑механики matrix

