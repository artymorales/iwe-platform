#!/usr/bin/env bash
# commit-gate.sh — G5: Commit Gate
# Проверка перед git commit: прочитать AGENTS.md/CLAUDE.md репо + capture-back.
# Использование: bash ~/iwe-platform/scripts/gates/commit-gate.sh [repo-path]
# Источник: DP.M.008 §8.2 (PACK), FMT protocol-work.md §3, WP-34
set -euo pipefail

REPO="${1:-$(pwd)}"
IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
LOG_DIR="${LOG_DIR:-$HOME/ds-strategy/logs}"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)
TZ="+03:00"

echo "=== G5 Commit Gate: $REPO ==="
echo ""

# 1. Проверка: есть ли AGENTS.md / CLAUDE.md?
AGENT_FILE=""
for candidate in "AGENTS.md" "CLAUDE.md" ".claude/CLAUDE.md"; do
  if [ -f "$REPO/$candidate" ]; then
    AGENT_FILE="$candidate"
    break
  fi
done

if [ -n "$AGENT_FILE" ]; then
  echo "  ✓ Найден $AGENT_FILE в $REPO"
  echo "  ⚠ Gate: прочитай $AGENT_FILE перед commit."
  echo "     Проверь — не нарушено ли правило?"
  echo ""
  # Показываем первые 5 строк для контекста
  echo "  Первые строки:"
  head -5 "$REPO/$AGENT_FILE" | sed 's/^/    /'
  echo "  ..."
else
  echo "  ✓ AGENTS.md/CLAUDE.md не найден — gate пройден"
fi

echo ""

# 2. Capture-back: есть ли изменения, затрагивающие memory/?
if [ -d "$REPO/.git" ]; then
  STAGED=$(cd "$REPO" && git diff --cached --name-only 2>/dev/null || true)
  if [ -n "$STAGED" ]; then
    echo "  Изменённые файлы:"
    echo "$STAGED" | while read -r f; do echo "    $f"; done
    echo ""

    # Проверяем: изменяли ли мы скрипты/конфиги, о которых есть записи в memory/?
    SCRIPTS_CHANGED=$(echo "$STAGED" | grep -E '^scripts/' || true)
    if [ -n "$SCRIPTS_CHANGED" ]; then
      echo "  ⚠ Gate (capture-back): изменены скрипты. Проверь memory/ на упоминания:"
      SCRIPTS_LIST=$(echo "$SCRIPTS_CHANGED" | tr '\n' ' ')
      echo "    grep -rl \"$(echo "$SCRIPTS_CHANGED" | head -1 | xargs basename)\" $IWE_DIR/memory/"
      echo ""
    fi

    # Проверка: изменены протоколы?
    PROTOCOLS_CHANGED=$(echo "$STAGED" | grep -E '^memory/protocols/' || true)
    if [ -n "$PROTOCOLS_CHANGED" ]; then
      echo "  ⚠ Gate (capture-back): изменены протоколы. Нужно обновить AGENTS.md?"
    fi
  fi
fi

echo ""

# 3. Логирование
mkdir -p "$LOG_DIR"
echo "{\"ts\":\"${DATE}T${TIME}${TZ}\",\"gate\":\"G5\",\"decision\":\"check\",\"repo\":\"$(basename "$REPO")\",\"agent_file\":\"${AGENT_FILE:-none}\"}" >> "$LOG_DIR/gate_log.jsonl"

echo "  ✓ G5 Commit Gate: проверен"
echo "     Лог: $LOG_DIR/gate_log.jsonl"
