#!/usr/bin/env bash
# fmt-version-check.sh — Проверка новой версии FMT-exocortex-template
#
# Использование:
#   bash fmt-version-check.sh          # Проверить и вывести статус
#   bash fmt-version-check.sh --quiet  # Только код возврата (0=актуально, 1=есть новая, 2=ошибка)
#   bash fmt-version-check.sh --notify # Записать результат в .fmt-update-available
#
# Встраивается в day-open.sh. Сравнивает последний git-тег upstream с версией в манифесте.
# Не требует GitHub Releases — использует git ls-remote --tags.

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

# --- Получение последнего тега через git ls-remote ---
# FMT использует git-теги (v0.34.1, v0.35.3...), а не GitHub Releases.
# Сравниваем по тегам, сортируем версионно.

LATEST_VERSION=""
LATEST_TAG=""
ERROR_MSG=""

GIT_TAGS=$(git ls-remote --tags "https://github.com/$FMT_SOURCE.git" 2>/dev/null || true)

if [ -n "$GIT_TAGS" ]; then
  LATEST_TAG=$(echo "$GIT_TAGS" | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | sed 's/^v//' | sort -V | tail -1 || echo "")
  if [ -n "$LATEST_TAG" ]; then
    LATEST_VERSION="${LATEST_TAG#v}"
  fi
fi

if [ -z "$LATEST_TAG" ]; then
  ERROR_MSG="Не удалось получить теги из git ls-remote (нет сети? неверный репозиторий?)"
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
    echo "v$LATEST_VERSION" > "$IWE_DIR/.fmt-update-available"
    echo "fmt_source=$FMT_SOURCE" >> "$IWE_DIR/.fmt-update-available"
  fi
  exit 1
else
  $QUIET || echo "✓ FMT актуален: v$CURRENT_VERSION"
  if $NOTIFY && [ -f "$IWE_DIR/.fmt-update-available" ]; then
    rm -f "$IWE_DIR/.fmt-update-available"
  fi
  exit 0
fi
