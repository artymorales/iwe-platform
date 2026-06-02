#!/usr/bin/env bash
# fmt-diff.sh — Сравнение локальной адаптации с новой версией FMT
#
# Использование:
#   bash fmt-diff.sh                        # Сравнить с последним релизом
#   bash fmt-diff.sh --version v0.35.0      # Сравнить с конкретной версией
#   bash fmt-diff.sh --check                # Только проверить (без diff)
#   bash fmt-diff.sh --quiet                # Без детальных diff'ов

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IWE_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST="$IWE_DIR/fmt-sync-manifest.json"

CHECK_ONLY=false
QUIET=false
TARGET_VERSION=""

for arg in "$@"; do
  case "$arg" in
    --check) CHECK_ONLY=true ;;
    --quiet) QUIET=true ;;
    --version=*) TARGET_VERSION="${arg#*=}" ;;
    --version) echo "--version requires a value"; exit 1 ;;
  esac
done

# --- 1. Чтение манифеста ---
if [ ! -f "$MANIFEST" ]; then
  echo "❌ Манифест не найден: $MANIFEST"
  exit 1
fi

CURRENT_VERSION=$(python3 -c "
import json
with open('$MANIFEST') as f:
    print(json.load(f).get('fmt_version', ''))
" 2>/dev/null || echo "")

FMT_SOURCE=$(python3 -c "
import json
with open('$MANIFEST') as f:
    print(json.load(f).get('fmt_source', 'TserenTserenov/FMT-exocortex-template'))
" 2>/dev/null || echo "TserenTserenov/FMT-exocortex-template")

if [ -z "$CURRENT_VERSION" ]; then
  echo "❌ Не удалось прочитать fmt_version из манифеста."
  exit 1
fi

CURRENT_TAG="v$CURRENT_VERSION"

# --- 2. Определяем целевую версию ---
if [ -n "$TARGET_VERSION" ]; then
  TARGET_TAG="v${TARGET_VERSION#v}"
  echo "🔍 Сравнение: $CURRENT_TAG → $TARGET_TAG"
else
  echo "🔍 Определяю последнюю версию FMT через CHANGELOG.md..."
  CHANGELOG_URL="https://raw.githubusercontent.com/$FMT_SOURCE/main/CHANGELOG.md"
  CHANGELOG_RAW=$(curl -sSfL "$CHANGELOG_URL" 2>/dev/null || true)
  TARGET_TAG=$(echo "$CHANGELOG_RAW" | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | head -1 | sed 's/^## \[//;s/\]//')

  if [ -z "$TARGET_TAG" ]; then
    echo "❌ Не удалось извлечь версию из CHANGELOG.md (нет сети? изменился формат?)"
    echo "   Укажите версию: bash fmt-diff.sh --version v0.35.0"
    exit 1
  fi
  TARGET_TAG="v$TARGET_TAG"
  echo "   Последняя: $TARGET_TAG (текущая: $CURRENT_TAG)"
fi

if [ "$CURRENT_TAG" = "$TARGET_TAG" ]; then
  echo ""
  echo "✓ FMT актуален: $CURRENT_TAG. Обновлений нет."
  exit 0
fi

# --- 3. Клонируем FMT для сравнения ---
TMPDIR=$(mktemp -d "/tmp/fmt-diff-$$-XXXXXX")
trap "rm -rf '$TMPDIR'" EXIT

echo ""
echo "📥 Клонирую $FMT_SOURCE..."
git clone --depth 50 "https://github.com/$FMT_SOURCE.git" "$TMPDIR/fmt" 2>/dev/null || {
  echo "❌ Ошибка клонирования."
  exit 1
}

cd "$TMPDIR/fmt"

OLD_EXISTS=false; NEW_EXISTS=false
git rev-parse --verify "$CURRENT_TAG" 2>/dev/null && OLD_EXISTS=true
git rev-parse --verify "$TARGET_TAG" 2>/dev/null && NEW_EXISTS=true

if ! $OLD_EXISTS; then
  echo "⚠ Тег $CURRENT_TAG не найден. Использую первый доступный..."
  CURRENT_TAG=$(git tag --list 'v*' | sort -V | head -1)
fi
if ! $NEW_EXISTS; then
  echo "⚠ Тег $TARGET_TAG не найден. Использую main..."
  TARGET_TAG="main"
fi

echo ""
echo "=========================================="
echo "  Diff FMT: $CURRENT_TAG → $TARGET_TAG"
echo "=========================================="
echo ""

# --- 4. Собираем все данные из манифеста в файл для итерации ---
python3 -c "
import json, sys

with open('$MANIFEST') as f:
    data = json.load(f)

# Deprecated files
dep = data.get('deprecated_files', [])
print('DEPRECATED_COUNT=' + str(len(dep)))
for d in dep:
    p = d.get('path', '')
    r = d.get('reason', '')
    print('DEPRECATED|' + p + '|' + r)

# Ignored patterns
for p in data.get('ignored', []):
    print('IGNORED|' + p)

# Files entries
for e in data.get('files', []):
    srcs = e.get('fmt_sources', [e.get('fmt_source', '')])
    if isinstance(srcs, str):
        srcs = [srcs]
    local = e['local']
    status = e.get('status', 'blue')
    note = e.get('note', '')
    src_list = ';'.join(srcs)
    print('FILE|' + local + '|' + status + '|' + note + '|' + src_list)
" > "$TMPDIR/manifest-data.txt"

# --- 5. Проверка deprecated ---
echo "--- 🔴 Устаревшие файлы (DEPRECATED) ---"
DEP_COUNT=$(grep -c '^DEPRECATED|' "$TMPDIR/manifest-data.txt" 2>/dev/null || true)
if [ "$DEP_COUNT" -eq 0 ]; then
  echo "  (нет устаревших файлов)"
else
  grep '^DEPRECATED|' "$TMPDIR/manifest-data.txt" | while IFS='|' read -r _ fpath reason; do
    echo "  - $fpath"
    echo "    Причина: ${reason:-не указана}"
    # Проверяем, есть ли аналог в манифесте
    while IFS='|' read -r _ local status _ srcs; do
      if echo "$srcs" | grep -qF "$fpath"; then
        echo "    → твой аналог: $local — ⚠ ПРОВЕРЬТЕ"
      fi
    done < <(grep '^FILE|' "$TMPDIR/manifest-data.txt")
  done
fi
echo ""

# --- 6. Анализ каждого файла из манифеста ---
echo "--- 📋 Файлы в манифесте ---"

TOTAL_FILES=$(grep -c '^FILE|' "$TMPDIR/manifest-data.txt" 2>/dev/null || true)

grep '^FILE|' "$TMPDIR/manifest-data.txt" | while IFS='|' read -r _ local status note srcs_raw; do

  # Разбиваем srcs обратно
  IFS=';' read -ra srcs <<< "$srcs_raw"

  ANY_NEW=false
  ANY_CHANGED=false
  ANY_MISSING=false
  CHANGE_LINES=""

  for src in "${srcs[@]}"; do
    [ -z "$src" ] && continue

    OLD_FILE="$TMPDIR/old-$(echo "$src" | tr '/' '-')"
    NEW_FILE="$TMPDIR/new-$(echo "$src" | tr '/' '-')"

    OLD_EXISTS_FILE=false; NEW_EXISTS_FILE=false
    git show "$CURRENT_TAG:$src" > "$OLD_FILE" 2>/dev/null && OLD_EXISTS_FILE=true
    git show "$TARGET_TAG:$src" > "$NEW_FILE" 2>/dev/null && NEW_EXISTS_FILE=true

    if ! $OLD_EXISTS_FILE && $NEW_EXISTS_FILE; then
      ANY_NEW=true
      CHANGE_LINES="$CHANGE_LINES  🔵 NEW: $src (появился в $TARGET_TAG)\n"
    elif $OLD_EXISTS_FILE && ! $NEW_EXISTS_FILE; then
      ANY_MISSING=true
      CHANGE_LINES="$CHANGE_LINES  🔴 REMOVED: $src (был в $CURRENT_TAG, нет в $TARGET_TAG)\n"
    elif $OLD_EXISTS_FILE && $NEW_EXISTS_FILE; then
      if ! diff -q "$OLD_FILE" "$NEW_FILE" >/dev/null 2>&1; then
        ANY_CHANGED=true
        ADDED=$(diff --unified=0 "$OLD_FILE" "$NEW_FILE" 2>/dev/null | grep -c '^+[^+]' || true)
        REMOVED=$(diff --unified=0 "$OLD_FILE" "$NEW_FILE" 2>/dev/null | grep -c '^-[^-]' || true)
        CHANGE_LINES="$CHANGE_LINES  🟡 CHANGED: $src (+$ADDED/-$REMOVED строк)\n"
      fi
    fi
  done

  # Вывод по файлу
  if $ANY_NEW && ! $ANY_CHANGED && ! $ANY_MISSING; then
    echo "[🔵 NEW]     $local"
    [ -n "$note" ] && echo "    Заметка: $note"
  elif $ANY_MISSING; then
    echo "[🔴 REMOVED] $local"
    [ -n "$note" ] && echo "    Заметка: $note"
  elif $ANY_CHANGED && ! $ANY_NEW && ! $ANY_MISSING; then
    echo "[🟡 CHANGED] $local"
    [ -n "$note" ] && echo "    Заметка: $note"
    if [ "$status" = "white" ]; then
      echo "    Рекомендация: применить изменения вручную (белый файл)"
    else
      echo "    Рекомендация: адаптировать вручную (голубой файл)"
    fi
  else
    echo "[⚪ OK]      $local — без изменений"
    continue
  fi

  # Показываем детали изменений
  echo -e "$CHANGE_LINES" | sed 's/^/    /'

  # Для белых файлов — показываем diff (если не --quiet)
  if ! $QUIET && [ "$status" = "white" ] && $ANY_CHANGED; then
    for src in "${srcs[@]}"; do
      [ -z "$src" ] && continue
      OLD_FILE="$TMPDIR/old-$(echo "$src" | tr '/' '-')"
      NEW_FILE="$TMPDIR/new-$(echo "$src" | tr '/' '-')"
      if [ -f "$OLD_FILE" ] && [ -f "$NEW_FILE" ] && ! diff -q "$OLD_FILE" "$NEW_FILE" >/dev/null 2>&1; then
        echo "    ─── $src ───"
        diff --unified=3 --label="$CURRENT_TAG:$src" --label="$TARGET_TAG:$src" \
          "$OLD_FILE" "$NEW_FILE" 2>/dev/null | sed 's/^/      /'
        echo ""
      fi
    done
  fi
  echo ""
done

# --- 7. Игнорируемые паттерны — быстрая проверка ---
echo "--- ⚪ Игнорируемая зона (ignored) ---"
IGNORED_CHANGES=0

grep '^IGNORED|' "$TMPDIR/manifest-data.txt" | while IFS='|' read -r _ pattern; do
  [ -z "$pattern" ] && continue
  DIR="${pattern%\*}"
  [ -z "$DIR" ] && continue

  FILES_OLD=$(git ls-tree -r --name-only "$CURRENT_TAG" 2>/dev/null | grep "^$DIR" || true)
  FILES_NEW=$(git ls-tree -r --name-only "$TARGET_TAG" 2>/dev/null | grep "^$DIR" || true)

  if [ "$FILES_OLD" != "$FILES_NEW" ]; then
    IGNORED_CHANGES=$((IGNORED_CHANGES + 1))
    echo "  ⚪ [$pattern] — изменения (пропускаются)"
  fi
done

if [ "$IGNORED_CHANGES" -eq 0 ]; then
  echo "  (изменений не обнаружено)"
fi

echo ""
echo "=========================================="
echo "  Итог: FMT $CURRENT_TAG → $TARGET_TAG"
echo "=========================================="
echo ""
echo "Рекомендация:"
echo "  1. Просмотри изменения в белых файлах и примени"
echo "  2. Для голубых — адаптируй вручную под Pi agent"
echo "  3. Обнови fmt_version в fmt-sync-manifest.json"
echo "  4. Закоммить изменения"
echo ""
