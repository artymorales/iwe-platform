#!/usr/bin/env bash
# week-close.sh — Закрытие недели в IWE
# Создаёт WeekPlan на следующую неделю, подводит итоги текущей.
# Запуск: bash ~/iwe-platform/scripts/week-close.sh
set -euo pipefail

IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-$HOME/ds-knowledge-index}"
DATE=$(date +%Y-%m-%d)
CUR_WEEK=$(date +%V)
NEXT_WEEK=$((10#$CUR_WEEK + 1))
# Корректировка перехода через год — упрощённо, просим пользователя проверить.
YEAR=$(date +%Y)

echo "=== Закрытие недели $CUR_WEEK ($DATE) ==="
echo ""

# 1. Проверка dirty-репозиториев
echo "--- Commit всех репозиториев ---"
for repo in "$IWE_DIR" "$STRATEGY_DIR" "$KNOWLEDGE_DIR"; do
  if [ -d "$repo/.git" ]; then
    cd "$repo"
    DIRTY=$(git status --short 2>/dev/null | wc -l)
    if [ "$DIRTY" -gt 0 ]; then
      echo "  → $repo: $DIRTY файлов"
      git add -A
      git commit -m "week-close: неделя $CUR_WEEK, $DATE"
      git push 2>/dev/null && echo "    ✓ Push OK" || echo "    ⚠ Push не удался"
    else
      echo "  ✓ $repo: чисто"
    fi
  fi
done
echo ""

# 2. Итоги недели
echo "--- Итоги недели $CUR_WEEK ---"
echo "  (Заполняется вручную или на стратегической сессии)"
echo ""

# 3. Создание WeekPlan на следующую неделю
WEEKPLAN="$STRATEGY_DIR/current/weekplan-${YEAR}-W${NEXT_WEEK}.md"
if [ ! -f "$WEEKPLAN" ]; then
  cat > "$WEEKPLAN" << EOF
# WeekPlan: Неделя $NEXT_WEEK ($YEAR)

## Цели недели
1. 

## Задачи (РП)
| № | Задача | Артефакт | Оценка | Статус |
|---|--------|----------|--------|--------|
| 1 | | | | открыта |

## Заметки


## Рефлексия (заполняется в конце недели)

EOF
  echo "  ✓ Создан WeekPlan: $(basename "$WEEKPLAN")"
else
  echo "  · WeekPlan уже существует"
fi
echo ""

# 4. Предложение: провести стратегическую сессию
echo "--- Рекомендация ---"
echo "  Рекомендуется провести стратегическую сессию:"
echo "  - Определить цели на неделю $NEXT_WEEK"
echo "  - Разобрать inbox в ds-strategy"
echo "  - Провести Capture-to-Pack по накопленным знаниям"
echo ""

echo "=== Неделя $CUR_WEEK закрыта ==="
