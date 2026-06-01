#!/usr/bin/env bash
# fmt-version-check.sh — Проверка новой версии FMT-exocortex-template
#
# Использование:
#   bash fmt-version-check.sh          # Проверить и вывести статус
#   bash fmt-version-check.sh --quiet  # Только код возврата (0=актуально, 1=есть новая, 2=ошибка)
#   bash fmt-version-check.sh --notify # Записать результат в .fmt-update-available
#
# Встраивается в day-open.sh. Не требует git-клонирования — только GitHub API.

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

# --- GitHub API: последний релиз ---
LATEST_VERSION=""
LATEST_URL=""
ERROR_MSG=""

GITHUB_OUTPUT=$(curl -sSfL \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$FMT_SOURCE/releases/latest" 2>/dev/null || true)

if [ -n "$GITHUB_OUTPUT" ]; then
  TAG=$(echo "$GITHUB_OUTPUT" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('tag_name',''))
except: print('')
" 2>/dev/null || echo "")

  if [ -n "$TAG" ]; then
    LATEST_VERSION="${TAG#v}"
    LATEST_URL=$(echo "$GITHUB_OUTPUT" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    print(d.get('html_url',''))
except: print('')
" 2>/dev/null || echo "")
  fi
fi

if [ -z "$LATEST_VERSION" ]; then
  # Fallback: нет сети или лимит API
  ERROR_MSG="Не удалось подключиться к GitHub API (лимит? нет сети?)"
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
    echo "   Запусти: bash $SCRIPT_DIR/fmt-diff.sh"
    [ -n "$LATEST_URL" ] && echo "   Релиз: $LATEST_URL"
  }
  if $NOTIFY; then
    echo "v$LATEST_VERSION" > "$IWE_DIR/.fmt-update-available"
    echo "fmt_source=$FMT_SOURCE" >> "$IWE_DIR/.fmt-update-available"
    [ -n "$LATEST_URL" ] && echo "url=$LATEST_URL" >> "$IWE_DIR/.fmt-update-available"
  fi
  exit 1
else
  $QUIET || echo "✓ FMT актуален: v$CURRENT_VERSION"
  if $NOTIFY && [ -f "$IWE_DIR/.fmt-update-available" ]; then
    rm -f "$IWE_DIR/.fmt-update-available"
  fi
  exit 0
fi
