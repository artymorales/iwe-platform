#!/usr/bin/env bash
# day-close.sh — Закрытие дня в IWE
# Запуск: bash ~/iwe-platform/scripts/day-close.sh
set -euo pipefail

IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-$HOME/ds-knowledge-index}"
DATE=$(date +%Y-%m-%d)

echo "=== Закрытие дня: $DATE ==="
echo ""

# 1. Проверка: есть ли заметка дня?
DAYNOTE="$STRATEGY_DIR/current/day-${DATE}.md"
if [ ! -f "$DAYNOTE" ]; then
  echo "  ⚠ Нет заметки дня. Создаю..."
  echo "  · Работа была без day-open?"
else
  echo "  ✓ Заметка дня: $(basename "$DAYNOTE")"
fi
echo ""

# 2. Творческий конвейер — проверка здоровья
#    Источник: PD.FORM.005 Creative Pipeline
#    БЛОКИРУЮЩЕЕ — Day Close

echo "--- Творческий конвейер ---"
PIPELINE_SCRIPT="$IWE_DIR/scripts/skills/creative-pipeline.sh"
if [ -x "$PIPELINE_SCRIPT" ]; then
  bash "$PIPELINE_SCRIPT" check || true
else
  echo "  ⚠ creative-pipeline.sh не найден (пропускаю)"
fi
echo ""

# 3. Commit + Push по всем репозиториям
echo "--- Commit + Push ---"
for repo in "$IWE_DIR" "$STRATEGY_DIR" "$KNOWLEDGE_DIR"; do
  if [ -d "$repo/.git" ]; then
    cd "$repo"
    DIRTY=$(git status --short 2>/dev/null | wc -l)
    if [ "$DIRTY" -gt 0 ]; then
      echo "  → $repo: $DIRTY файлов"
      git add -A
      git commit -m "day-close: $DATE"
      git push 2>/dev/null && echo "    ✓ Push OK" || echo "    ⚠ Push не удался"
    else
      echo "  ✓ $repo: чисто"
    fi
  elif [ -d "$repo" ]; then
    echo "  · $repo: не git-репозиторий (пропущен)"
  fi
done
echo ""

# 4. Итог дня
echo "--- Итог дня ---"
echo "  Дата: $DATE"
echo "  Репозитории: закоммичены"
echo ""
echo "=== День закрыт ==="
