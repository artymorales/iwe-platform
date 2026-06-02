#!/usr/bin/env bash
# fmt-version-check.sh — Проверка новой версии FMT-exocortex-template
#
# Использование:
#   bash fmt-version-check.sh          # Проверить и вывести статус
#   bash fmt-version-check.sh --quiet  # Только код возврата (0=актуально, 1=есть новая, 2=ошибка)
#   bash fmt-version-check.sh --notify # Записать результат в .fmt-update-available (+ ченжлог)
#
# Встраивается в day-open.sh. Парсит CHANGELOG.md (Keep a Changelog) из upstream main.
# GitHub Releases — нет, git-теги — устаревшие (последний 0.29.6). CHANGELOG.md — единственный
# актуальный источник версий.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IWE_DIR="$(dirname "$SCRIPT_DIR")"
MANIFEST="$IWE_DIR/fmt-sync-manifest.json"
PARAMS="$IWE_DIR/params.yaml"
QUIET=false
NOTIFY=false

for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=true ;;
    --notify) NOTIFY=true ;;
  esac
done

# --- Чтение текущей версии из манифеста ---
if [ ! -f "$MANIFEST" ]; then
  $QUIET || echo "❌ Манифест не найден: $MANIFEST"
  exit 2
fi

CURRENT_VERSION=$(python3 -c "
import json
with open('$MANIFEST') as f:
    data = json.load(f)
print(data.get('fmt_version', '0.0.0'))
" 2>/dev/null || grep '"fmt_version"' "$MANIFEST" | head -1 | sed 's/.*"fmt_version"[[:space:]]*:[[:space:]]*"//;s/".*//')

FMT_SOURCE=$(python3 -c "
import json
with open('$MANIFEST') as f:
    data = json.load(f)
print(data.get('fmt_source', 'TserenTserenov/FMT-exocortex-template'))
" 2>/dev/null || echo "TserenTserenov/FMT-exocortex-template")

# --- Получение CHANGELOG.md из upstream main ---
# FMT не имеет GitHub Releases. git-теги застряли на 0.29.6.
# Актуальная версия — первый заголовок ## [X.Y.Z] в CHANGELOG.md на main.

CHANGELOG_URL="https://raw.githubusercontent.com/$FMT_SOURCE/main/CHANGELOG.md"
LATEST_VERSION=""
ERROR_MSG=""
CHANGELOG_ENTRY=""

CHANGELOG=$(curl -sSfL "$CHANGELOG_URL" 2>/dev/null || true)

if [ -z "$CHANGELOG" ]; then
  ERROR_MSG="Не удалось загрузить CHANGELOG.md (нет сети? неверный URL?)"
else
  # Парсим первый заголовок ## [X.Y.Z] — это последняя версия
  LATEST_VERSION=$(echo "$CHANGELOG" | grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' | head -1 | sed 's/^## \[//;s/\]//')

  # Извлекаем ченжлог-запись для этой версии (от заголовка до следующего ## [...] или ---)
  if $NOTIFY && [ -n "$LATEST_VERSION" ]; then
    # Сохраняем ченжлог во временный файл, чтобы Python не ломался на спецсимволах
    CHANGELOG_TMP=$(mktemp "/tmp/fmt-changelog-$$-XXXXXX")
    echo "$CHANGELOG" > "$CHANGELOG_TMP"
    CHANGELOG_ENTRY=$(python3 -c "
import re

with open('$CHANGELOG_TMP') as f:
    text = f.read()

# Ищем блок от заголовка нужной версии до следующего заголовка ## [X.Y.Z]
pattern = r'## \[' + re.escape('$LATEST_VERSION') + r'\].*?(?=\n## \[[0-9]+\.[0-9]+\.[0-9]+\]|\n---|\Z)'
m = re.search(pattern, text, re.DOTALL)
if m:
    entry = m.group(0).strip()
    print(entry)
" 2>/dev/null || true)
    rm -f "$CHANGELOG_TMP"
  fi
fi

if [ -z "$LATEST_VERSION" ] && [ -z "$ERROR_MSG" ]; then
  ERROR_MSG="Не удалось извлечь версию из CHANGELOG.md (изменился формат?)"
fi

# --- Сравнение версий ---
if [ -n "$ERROR_MSG" ]; then
  $QUIET || echo "⚠ $ERROR_MSG"
  exit 2
fi

# Сравнение через sort -V (версионное)
HIGHER=$(printf '%s\n' "$CURRENT_VERSION" "$LATEST_VERSION" | sort -V | tail -1)

if [ "$HIGHER" = "$LATEST_VERSION" ] && [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
  # Есть новая версия
  $QUIET || {
    echo "📦 Доступна новая версия FMT: v$LATEST_VERSION (текущая: v$CURRENT_VERSION)"
    echo "   Запусти: bash $SCRIPT_DIR/fmt-diff.sh --version=v$LATEST_VERSION"
    echo "   Или:     bash $SCRIPT_DIR/update.sh --version=v$LATEST_VERSION"
  }
  if $NOTIFY; then
    {
      echo "v$LATEST_VERSION"
      echo "current=v$CURRENT_VERSION"
      echo "fmt_source=$FMT_SOURCE"
    } > "$IWE_DIR/.fmt-update-available"

    # Сохраняем ченжлог отдельно
    if [ -n "$CHANGELOG_ENTRY" ]; then
      {
        echo "# Что нового в FMT v$LATEST_VERSION"
        echo ""
        echo "$CHANGELOG_ENTRY"
      } > "$IWE_DIR/.fmt-update-changelog.md"
    fi

    # Выводим ченжлог, если есть
    if [ -n "$CHANGELOG_ENTRY" ]; then
      echo ""
      echo "$CHANGELOG_ENTRY"
      echo ""
    fi
  fi
  exit 1
else
  $QUIET || echo "✓ FMT актуален: v$CURRENT_VERSION (upstream: v$LATEST_VERSION)"
  if $NOTIFY && [ -f "$IWE_DIR/.fmt-update-available" ]; then
    rm -f "$IWE_DIR/.fmt-update-available" "$IWE_DIR/.fmt-update-changelog.md" 2>/dev/null || true
  fi
  exit 0
fi
