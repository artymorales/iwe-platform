#!/usr/bin/env bash
# close-gate.sh — G7: Close Gate
# Проверка перед закрытием: commit+push по 3 репозиториям + capture.
# Использование: bash ~/iwe-platform/scripts/gates/close-gate.sh [--no-commit]
# Источник: Правило 2 AGENTS.md, FMT protocol-work.md §3 (Capture-back), WP-34
set -euo pipefail

IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-$HOME/ds-knowledge-index}"
LOG_DIR="${LOG_DIR:-$HOME/ds-strategy/logs}"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)
TZ="+03:00"
NO_COMMIT=false

if [ "${1:-}" = "--no-commit" ]; then
  NO_COMMIT=true
fi

echo "=== G7 Close Gate: $DATE ==="
echo ""

# 0. Session Context Gate (БЛОКИРУЮЩЕЕ) — проверка перед commit
CTX="$STRATEGY_DIR/current/session-context.md"
if [ -f "$CTX" ]; then
  CTX_DATE=$(date -r "$CTX" +%Y-%m-%d 2>/dev/null || echo "unknown")
  if [ "$CTX_DATE" != "$DATE" ]; then
    echo "  ❌ Session Context Gate: session-context.md не обновлён сегодня!"
    echo "     Последнее обновление: $CTX_DATE, сегодня: $DATE"
    echo "     Запиши ход мысли перед закрытием (close.md §2.6)."
    echo ""
    echo "     Для ручного обновления:"
    echo "       vim $CTX"
    echo ""
    exit 1
  fi
  echo "  ✓ Session Context: обновлён $CTX_DATE"
else
  echo "  ⚠ Session Context: файл отсутствует. Создай заглушку (session-context.md §Создание)."
fi
echo ""

DIRTY_COUNT=0
PUSHED_COUNT=0

for repo in "$IWE_DIR" "$STRATEGY_DIR" "$KNOWLEDGE_DIR"; do
  if [ ! -d "$repo/.git" ]; then
    echo "  · $(basename "$repo"): не git (пропущен)"
    continue
  fi

  cd "$repo"
  DIRTY=$(git status --short 2>/dev/null | wc -l | tr -d ' ')

  if [ "$DIRTY" -gt 0 ]; then
    DIRTY_COUNT=$((DIRTY_COUNT + 1))
    echo "  ⚠ $(basename "$repo"): $DIRTY незакоммиченных файлов"

    if [ "$NO_COMMIT" = false ]; then
      echo "    → commit + push..."
      git add -A
      git commit -m "close-gate: $DATE" 2>/dev/null && echo "    ✓ commit OK" || echo "    · нечего коммитить"
      git push 2>/dev/null && echo "    ✓ push OK" || echo "    ⚠ push не удался"
      PUSHED_COUNT=$((PUSHED_COUNT + 1))
    else
      echo "    (--no-commit: пропущен)"
      # Показываем что именно изменено
      git status --short | head -10 | sed 's/^/      /'
    fi
  else
    echo "  ✓ $(basename "$repo"): чисто"
  fi
done

echo ""

# 2. Напоминание: Capture-to-Pack
echo "  Capture Gate (Правило 4):"
echo "    Появилось ли знание для записи?"
echo "    → Правило → memory/distinctions.md"
echo "    → Протокол → memory/protocols/"
echo "    → Доменное → ds-knowledge-index/captures/"
echo "    → Урок → ds-knowledge-index/drafts/"
echo ""

# 3. Лог
mkdir -p "$LOG_DIR"
echo "{\"ts\":\"${DATE}T${TIME}${TZ}\",\"gate\":\"G7\",\"decision\":\"$([ "$NO_COMMIT" = true ] && echo 'check' || echo 'pass')\",\"dirty_repos\":$DIRTY_COUNT,\"pushed\":$PUSHED_COUNT,\"no_commit\":$NO_COMMIT}" >> "$LOG_DIR/gate_log.jsonl"

echo "  ✓ G7 Close Gate: проверен"
echo "     Лог: $LOG_DIR/gate_log.jsonl"
