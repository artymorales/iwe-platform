#!/usr/bin/env bash
# update.sh — Применение обновлений FMT к локальной IWE
#
# Использование:
#   bash update.sh                          # Применить последнюю версию
#   bash update.sh --version v0.35.0        # Применить конкретную версию
#   bash update.sh --check                  # Только проверить, ничего не менять
#   bash update.sh --dry-run                # Показать что будет сделано, без изменений
#   bash update.sh --force                  # Применить все белые файлы без запроса
#   bash update.sh --manifest-update        # Только обновить manifest (версию), без diff
#
# Принцип работы:
#   1. Клонирует FMT на целевой тег
#   2. Для каждого файла из fmt-sync-manifest.json сверяет FMT-версию с local-версией
#   3. Белые файлы (white) — применяет изменения с git-merge подходом
#   4. Голубые файлы (blue) — показывает diff и запрашивает решение
#   5. AUTHOR-ONLY зоны в протоколах — сохраняет при обновлении
#   6. Обновляет fmt_version в манифесте и params.yaml

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IWE_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST="$IWE_DIR/fmt-sync-manifest.json"
PARAMS="$IWE_DIR/params.yaml"

CHECK_ONLY=false
DRY_RUN=false
FORCE=false
MANIFEST_ONLY=false
TARGET_VERSION=""

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    --manifest-update) MANIFEST_ONLY=true ;;
    --version=*) TARGET_VERSION="${arg#*=}" ;;
    --version) echo "❌ --version требует значения. Пример: --version=v0.35.0"; exit 1 ;;
    --help|-h)
      echo "Использование: bash update.sh [опции]"
      echo ""
      echo "Опции:"
      echo "  --check              Проверить наличие обновлений, без изменений"
      echo "  --dry-run            Показать что будет сделано, без изменений"
      echo "  --force              Применить белые файлы без запроса"
      echo "  --manifest-update    Только обновить номер версии в манифесте, без diff"
      echo "  --version=vX.Y.Z     Применить конкретную версию"
      echo "  --help               Эта справка"
      exit 0
      ;;
  esac
done

# ===== Вспомогательные функции =====

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
err()   { echo -e "${RED}✗${NC} $1"; }
header(){ echo -e "\n${BLUE}══════════════════════════════════════${NC}"; echo -e "${BLUE}  $1${NC}"; echo -e "${BLUE}══════════════════════════════════════${NC}"; }

# ===== 1. Чтение манифеста =====

if [ ! -f "$MANIFEST" ]; then
  err "Манифест не найден: $MANIFEST"
  echo "  Создай fmt-sync-manifest.json перед запуском update.sh"
  exit 1
fi

# Чтение полей через Python (надёжнее grep при сложной вложенности)
read_manifest() {
  python3 -c "
import json, sys
with open('$MANIFEST') as f:
    data = json.load(f)
$1
" 2>/dev/null
}

CURRENT_VERSION=$(read_manifest "print(data.get('fmt_version', '0.0.0'))")
FMT_SOURCE=$(read_manifest "print(data.get('fmt_source', 'TserenTserenov/FMT-exocortex-template'))")

# ===== 2. Определение целевой версии =====

if [ -n "$TARGET_VERSION" ]; then
  TARGET_TAG="v${TARGET_VERSION#v}"
  info "Целевая версия: $TARGET_TAG"
elif $MANIFEST_ONLY; then
  # manifest-update версию не трогает — она задаётся отдельным флагом
  info "Режим: только обновление манифеста"
  TARGET_TAG=""
else
  info "Проверяю последнюю версию FMT через CHANGELOG.md..."
  CHANGELOG_URL="https://raw.githubusercontent.com/$FMT_SOURCE/main/CHANGELOG.md"
  CHANGELOG_RAW=$(curl -sSfL "$CHANGELOG_URL" 2>/dev/null || true)
  TARGET_TAG=$(echo "$CHANGELOG_RAW" | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | head -1 | sed 's/^## \[//;s/\]//')

  if [ -z "$TARGET_TAG" ]; then
    err "Не удалось извлечь версию из CHANGELOG.md (нет сети? изменился формат?)"
    echo "  Укажи версию явно: bash update.sh --version=v0.35.0"
    exit 1
  fi
  TARGET_TAG="v$TARGET_TAG"
  TARGET_VERSION="${TARGET_TAG#v}"
  info "Последняя версия: $TARGET_TAG (текущая: v$CURRENT_VERSION)"
fi

# ===== 3. Сравнение версий =====

if [ -z "$TARGET_TAG" ]; then
  if $MANIFEST_ONLY; then
    warn "Без --version= не указана целевая версия. Использую текущую: v$CURRENT_VERSION"
    TARGET_TAG="v$CURRENT_VERSION"
  else
    err "Целевая версия не определена. Используй --version=vX.Y.Z"
    exit 1
  fi
fi

HIGHER=$(printf '%s\n' "v$CURRENT_VERSION" "$TARGET_TAG" | sort -V | tail -1)
if [ "$HIGHER" != "$TARGET_TAG" ] && [ "$TARGET_TAG" != "v$CURRENT_VERSION" ]; then
  warn "Целевая версия $TARGET_TAG ниже или равна текущей v$CURRENT_VERSION."
  echo "  Если нужно откатиться — используй --force."
  echo "  Или укажи более новую версию."
  exit 0
fi

if [ "$TARGET_TAG" = "v$CURRENT_VERSION" ] && ! $MANIFEST_ONLY; then
  ok "FMT уже на версии v$CURRENT_VERSION. Обновлений нет."
  exit 0
fi

# ===== 4. Клонирование FMT =====

header "Клонирование FMT ($FMT_SOURCE @ $TARGET_TAG)"

TMPDIR=$(mktemp -d "/tmp/fmt-update-$$-XXXXXX")
trap "rm -rf '$TMPDIR'" EXIT

git clone --depth 50 "https://github.com/$FMT_SOURCE.git" "$TMPDIR/fmt" 2>/dev/null || {
  err "Ошибка клонирования $FMT_SOURCE"
  echo "  Проверь доступ к GitHub или имя репозитория в манифесте."
  exit 1
}

cd "$TMPDIR/fmt"

# Проверяем, что тег существует (FMT не тегирует CHANGELOG-версии — всегда clone main)
if ! git rev-parse --verify "$TARGET_TAG" 2>/dev/null; then
  warn "Git-тег $TARGET_TAG не найден. FMT не тегирует версии из CHANGELOG."
  warn "Использую main для кода, версия в манифесте будет $TARGET_TAG."
  # TARGET_TAG и TARGET_VERSION оставляем из CHANGELOG — они верны
fi

info "FMT клонирован. Тег: $TARGET_TAG"

if $CHECK_ONLY; then
  ok "Проверка завершена. Новая версия: $TARGET_TAG"
  echo "  Для применения: bash update.sh --version=$TARGET_VERSION"
  rm -rf "$TMPDIR"
  exit 0
fi

# ===== 5. Sha256 хэши для idempotency =====

# Вычисляем sha256 FMT-версии файла (чтобы не переприменять то же самое)
fmt_sha256() {
  local filepath="$1"
  if [ -f "$TMPDIR/fmt/$filepath" ]; then
    shasum -a 256 "$TMPDIR/fmt/$filepath" 2>/dev/null | cut -d' ' -f1
  else
    echo ""
  fi
}

# ===== 6. Функция сохранения AUTHOR-ONLY зон =====

preserve_author_only() {
  local local_file="$1"
  local temp_file="$2"

  if [ ! -f "$local_file" ]; then
    return 1  # Локального файла нет — нечего сохранять
  fi

  # Извлекаем AUTHOR-ONLY блоки из локального файла
  python3 -c "
import re

with open('$local_file') as f:
    content = f.read()

# Находим все AUTHOR-ONLY зоны
author_blocks = re.findall(
    r'<!-- AUTHOR-ONLY:.*?-->.*?<!-- /AUTHOR-ONLY -->',
    content,
    re.DOTALL
)

if not author_blocks:
    exit(1)

# Сохраняем в temp-файл
with open('$temp_file', 'w') as f:
    for block in author_blocks:
        f.write(block + '\n\n')
print(f'Saved {len(author_blocks)} AUTHOR-ONLY blocks')
exit(0)
" 2>/dev/null && return 0

  return 1
}

apply_author_only() {
  local local_file="$1"
  local author_file="$2"

  if [ ! -f "$author_file" ]; then
    return 0  # Нет блоков — ничего не делать
  fi

  # Вставляем AUTHOR-ONLY блоки в обновлённый файл (после последнего --- если есть frontmatter)
  python3 -c "
with open('$local_file') as f:
    content = f.read()

with open('$author_file') as f:
    author_blocks = f.read()

# Вставка в конец файла
with open('$local_file', 'w') as f:
    f.write(content)
    if not content.endswith('\n'):
        f.write('\n')
    f.write('\n')
    f.write(author_blocks)

print(f'Applied AUTHOR-ONLY blocks to $local_file')
" 2>/dev/null

  rm -f "$author_file"
}

# ===== 7. Сборка sha256-слепка текущих FMT-версий =====

# Если файл sha256.json ещё не создавался — создаём
SHA256_FILE="$IWE_DIR/fmt-sha256.json"
if [ ! -f "$SHA256_FILE" ]; then
  # Создаём слепок sha256 для текущей версии по манифесту
  python3 -c "
import json

with open('$MANIFEST') as f:
    manifest = json.load(f)

sha256_map = {}
for entry in manifest.get('files', []):
    srcs = entry.get('fmt_sources', [entry.get('fmt_source', '')])
    if isinstance(srcs, str):
        srcs = [srcs]
    for src in srcs:
        if src:
            sha256_map[src] = ''

with open('$SHA256_FILE', 'w') as f:
    json.dump({'v$CURRENT_VERSION': sha256_map}, f, indent=2)
print('Created sha256 snapshot for v$CURRENT_VERSION')
" 2>/dev/null || warn "Не удалось создать sha256-слепок"
fi

# ===== 8. Функция применения diff =====

apply_diff() {
  local local_path="$1"    # путь относительно ~/
  local fmt_path="$2"      # путь в FMT
  local file_type="$3"     # white/blue
  local note="$4"

  local resolved
  # Разворачиваем ~/
  resolved="${local_path/#\~\//$HOME/}"
  local full_path
  full_path="$(cd "$IWE_DIR" 2>/dev/null && realpath "$(dirname "$resolved")" 2>/dev/null || dirname "$resolved")/$(basename "$resolved")"

  # Если файл идёт в другой репозиторий (ds-strategy/)
  if [[ "$local_path" == *"ds-strategy"* ]]; then
    full_path="$HOME/$local_path"
  else
    full_path="$IWE_DIR/$local_path"
  fi

  local fmt_file="$TMPDIR/fmt/$fmt_path"

  # Где файл сейчас
  local local_exists=false
  if [ -f "$full_path" ]; then
    local_exists=true
  fi

  if [ ! -f "$fmt_file" ]; then
    if [ "$file_type" = "white" ]; then
      if $local_exists; then
        echo "[🔴 REMOVED] $local_path (файл исчез в FMT)"
      fi
    fi
    return 0
  fi

  # Определяем статус
  if ! $local_exists; then
    if [ "$file_type" = "white" ]; then
      echo "[🔵 NEW]     $local_path"
      if $DRY_RUN; then
        echo "      → будет создан из $fmt_path"
      else
        mkdir -p "$(dirname "$full_path")"
        cp "$fmt_file" "$full_path"
        ok "$local_path — создан из FMT"
      fi
    else
      echo "[🔵 NEW]     $local_path (blue — требуется адаптация)"
      if $DRY_RUN; then
        echo "      → будет скопирован для ручной адаптации"
      else
        mkdir -p "$(dirname "$full_path")"
        cp "$fmt_file" "$full_path"
        ok "$local_path — скопирован, требуется адаптация"
      fi
    fi
    return 0
  fi

  # Файл существует локально — сравниваем
  local local_sha=$(shasum -a 256 "$full_path" 2>/dev/null | cut -d' ' -f1)
  local fmt_sha=$(shasum -a 256 "$fmt_file" 2>/dev/null | cut -d' ' -f1)

  # Если FMT-файл не изменился — пропускаем
  local fmt_sha_prev=""
  if [ -f "$SHA256_FILE" ]; then
    fmt_sha_prev=$(python3 -c "
import json
with open('$SHA256_FILE') as f:
    data = json.load(f)
print(data.get(list(data.keys())[0], {}).get('$fmt_path', ''))
" 2>/dev/null || echo "")
  fi

  if [ -n "$fmt_sha_prev" ] && [ "$fmt_sha" = "$fmt_sha_prev" ]; then
    # FMT не менялся — пропускаем
    return 0
  fi

  # Сравниваем локальный файл с FMT-оригиналом
  if [ "$local_sha" = "$fmt_sha" ] && $local_exists; then
    # Файлы идентичны — обновлять нечего
    return 0
  fi

  # Есть расхождение
  local added=0
  local removed=0
  local diff_lines=""

  if $local_exists; then
    added=$(diff --unified=0 "$full_path" "$fmt_file" 2>/dev/null | grep -c '^+[^+]' || true)
    removed=$(diff --unified=0 "$full_path" "$fmt_file" 2>/dev/null | grep -c '^-[^-]' || true)
    diff_lines=$(diff --unified=3 --label="local:$local_path" --label="fmt:$fmt_path" \
      "$full_path" "$fmt_file" 2>/dev/null || true)
  fi

  # ---- Белые файлы (white) — auto-apply с сохранением адаптации ----
  if [ "$file_type" = "white" ]; then
    echo "[🟡 CHANGED] $local_path (+$added/-$removed) — white, авто-применение"

    if $DRY_RUN; then
      echo "      → будет обновлён из FMT"
      return 0
    fi

    if ! $FORCE; then
      echo ""
      echo "    ─── $local_path ───"
      echo "$diff_lines" | sed 's/^/      /'
      echo ""
      echo -n "    Применить изменения? [Y/n/browse]: "
      read -r answer
      case "$answer" in
        n|N|no|нет) warn "Пропущено: $local_path"; return 0 ;;
        b|browse)
          # Показать полный diff и повторить вопрос
          echo "$diff_lines" | less -R
          echo -n "    Применить изменения сейчас? [Y/n]: "
          read -r answer2
          case "$answer2" in
            n|N|no|нет) warn "Пропущено: $local_path"; return 0 ;;
            *) ;; # apply
          esac
          ;;
        *) ;; # apply
      esac
    fi

    # Сохраняем AUTHOR-ONLY зоны
    local author_temp=$(mktemp "/tmp/fmt-author-$$-XXXXXX")
    preserve_author_only "$full_path" "$author_temp"

    # Копируем новый FMT-файл
    cp "$fmt_file" "$full_path"

    # Восстанавливаем AUTHOR-ONLY зоны
    apply_author_only "$full_path" "$author_temp"

    ok "$local_path — обновлён"
  fi

  # ---- Голубые файлы (blue) — ручная адаптация ----
  if [ "$file_type" = "blue" ]; then
    echo "[🟡 CHANGED] $local_path (+$added/-$removed) — blue, требуется адаптация"
    [ -n "$note" ] && echo "    Заметка: $note"

    if $DRY_RUN; then
      echo "      → будет показан diff для ручной адаптации"
      return 0
    fi

    echo ""
    echo "    ─── $local_path ───"
    echo "$diff_lines" | sed 's/^/      /'
    echo ""

    # Сохраняем новую версию FMT рядом для справки
    local fmt_backup="$full_path.fmt-v$TARGET_VERSION"
    cp "$fmt_file" "$fmt_backup"
    info "Новая FMT-версия сохранена: $fmt_backup"
    echo "    Действие: адаптируй вручную. Diff показан выше."
    echo "    Новая версия FMT: $fmt_backup"
  fi
}

# ===== 9. Основной цикл обновления =====

header "Применение обновлений: v$CURRENT_VERSION → $TARGET_TAG"

TOTAL_FILES=0
UPDATED_FILES=0
SKIPPED_FILES=0
BLUE_FILES=0

# Обрабатываем каждый файл из манифеста
python3 -c "
import json

with open('$MANIFEST') as f:
    data = json.load(f)

for entry in data.get('files', []):
    local = entry['local']
    srcs = entry.get('fmt_sources', [entry.get('fmt_source', '')])
    if isinstance(srcs, str):
        srcs = [srcs]
    status = entry.get('status', 'blue')
    note = entry.get('note', '')

    for src in srcs:
        if src:
            print(f'{local}|{src}|{status}|{note}')
" 2>/dev/null | while IFS='|' read -r local_path fmt_path file_type note; do
  apply_diff "$local_path" "$fmt_path" "$file_type" "$note"
done

echo ""

# ===== 10. Missing white files — предложить создать =====

MISSING_COUNT=$(read_manifest "print(len(data.get('missing_white', [])))")

if [ "$MISSING_COUNT" -gt 0 ]; then
  header "Отсутствующие белые файлы (missing_white)"

  read_manifest "
for entry in data.get('missing_white', []):
    print(entry)
" 2>/dev/null | while IFS= read -r fpath; do
    echo "  [⚪ MISSING] $fpath — отсутствует в твоей IWE"
    echo -n "    Создать из FMT? [Y/n]: "
    read -r answer
    case "$answer" in
      n|N|no|нет)
        warn "Пропущено"
        ;;
      *)
        # Ищем источник в FMT
        fmt_path="${fpath#memory/}"
        fmt_path="memory/$fmt_path"
        fmt_file="$TMPDIR/fmt/$fmt_path"
        if [ -f "$fmt_file" ]; then
          if [[ "$fpath" == *"ds-strategy"* ]]; then
            target="$HOME/$fpath"
          else
            target="$IWE_DIR/$fpath"
          fi
          mkdir -p "$(dirname "$target")"
          cp "$fmt_file" "$target"
          ok "$fpath — создан из FMT"
        else
          warn "Источник в FMT не найден: $fmt_path"
        fi
        ;;
    esac
  done
  echo ""
fi

# ===== 11. Проверка deprecated файлов =====

DEP_COUNT=$(read_manifest "print(len(data.get('deprecated_map', {})))")
if [ "$DEP_COUNT" -gt 0 ]; then
  header "Устаревшие файлы (deprecated)"

  read_manifest "
for old, new in data.get('deprecated_map', {}).items():
    print(f'{old}|{new}')
" 2>/dev/null | while IFS='|' read -r old_path new_path; do
    if [ -n "$new_path" ]; then
      echo "  [⚪ REDIRECT] $old_path → $new_path"
    else
      echo "  [⚪ REMOVED] $old_path — удалён из FMT"
    fi
  done
  echo ""
fi

# ===== 12. Обновление sha256-слепка =====

header "Финализация"

# Собираем sha256 для нового FMT
python3 -c "
import json, hashlib, os

with open('$MANIFEST') as f:
    manifest = json.load(f)

sha256_map = {}
for entry in manifest.get('files', []):
    srcs = entry.get('fmt_sources', [entry.get('fmt_source', '')])
    if isinstance(srcs, str):
        srcs = [srcs]
    for src in srcs:
        if src:
            fpath = '$TMPDIR/fmt/' + src
            if os.path.isfile(fpath):
                with open(fpath, 'rb') as f:
                    sha256_map[src] = hashlib.sha256(f.read()).hexdigest()
            else:
                sha256_map[src] = ''
            sha256_map[src] = sha256_map.get(src, '')

with open('$SHA256_FILE', 'w') as f:
    json.dump({'$TARGET_TAG': sha256_map}, f, indent=2)
print('sha256-слепок обновлён: $SHA256_FILE')
" 2>/dev/null || warn "Не удалось обновить sha256-слепок"

# ===== 13. Обновление манифеста =====

# Обновляем fmt_version в манифесте
python3 -c "
import json

with open('$MANIFEST') as f:
    data = json.load(f)

old_version = data.get('fmt_version', '')
data['fmt_version'] = '${TARGET_VERSION#v}'
data['synced_by'] = 'update.sh'
data['synced_at'] = '$(date +%Y-%m-%d)'

# Обновляем fmt_version_synced для каждого файла
for entry in data.get('files', []):
    entry['fmt_version_synced'] = '${TARGET_VERSION#v}'

with open('$MANIFEST', 'w') as f:
    json.dump(data, f, indent=2)
print(f'Манифест обновлён: old={old_version} → ${TARGET_VERSION#v}')
" 2>/dev/null || err "Не удалось обновить манифест"

# ===== 14. Обновление params.yaml =====

if [ -f "$PARAMS" ]; then
  # Обновляем fmt_version и fmt_last_check
  sed_inplace() {
    if sed --version >/dev/null 2>&1; then
      sed -i "$@"
    else
      sed -i '' "$@"
    fi
  }
  sed_inplace "s/^fmt_version:.*/fmt_version: \"${TARGET_VERSION#v}\"/" "$PARAMS"
  sed_inplace "s/^fmt_last_check:.*/fmt_last_check: $(date +%Y-%m-%d)/" "$PARAMS"
  ok "params.yaml обновлён: fmt_version = ${TARGET_VERSION#v}"
fi

# ===== 15. Итог =====

header "Обновление завершено"
echo ""
echo "  FMT:      v$CURRENT_VERSION → ${TARGET_TAG#v}"
echo "  Манифест: $MANIFEST"
echo "  Sha256:   $SHA256_FILE"
echo ""
echo "Рекомендация:"
echo "  1. Проверь изменения: git diff"
echo "  2. Адаптируй голубые (blue) файлы вручную"
echo "  3. Закоммить: git add -A && git commit -m 'fmt: update to ${TARGET_TAG#v}'"
echo ""

# Очистка
rm -rf "$TMPDIR"
