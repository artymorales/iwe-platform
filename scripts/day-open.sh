#!/usr/bin/env bash
# day-open.sh — Открытие дня в IWE
# Запуск: bash ~/iwe-platform/scripts/day-open.sh
set -euo pipefail

IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-$HOME/ds-knowledge-index}"
DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u)  # 1=Пн, 7=Вс
WEEK_NUM=$(date +%V)

echo "=== Открытие дня: $DATE ==="
echo ""

# 0. Проверка версии FMT-шаблона
if [ -f "$IWE_DIR/params.yaml" ]; then
  FMT_CHECK=$(grep 'fmt_check_on_open:' "$IWE_DIR/params.yaml" | grep -c 'true' || true)
  if [ "$FMT_CHECK" -gt 0 ]; then
    CHECK_RESULT=0
    bash "$IWE_DIR/scripts/fmt-version-check.sh" --quiet --notify 2>/dev/null && CHECK_RESULT=$? || CHECK_RESULT=$?
    if [ "$CHECK_RESULT" -eq 1 ]; then
      NEW_VER=$(cat "$IWE_DIR/.fmt-update-available" 2>/dev/null | head -1 || echo "?")
      echo "  📦 Доступна новая версия FMT: $NEW_VER"
      echo "    bash $IWE_DIR/scripts/fmt-diff.sh — просмотр изменений"
    fi
  fi
fi
echo ""

# 1. Pull репозиториев
echo "--- Синхронизация репозиториев ---"
for repo in "$IWE_DIR" "$STRATEGY_DIR" "$KNOWLEDGE_DIR"; do
  if [ -d "$repo/.git" ]; then
    echo "  Pull: $repo"
    (cd "$repo" && git pull --rebase 2>/dev/null && echo "    OK") || echo "    Пропущен (dirty/net)"
  fi
done
echo ""

# 2. Проверка: был ли Day Open сегодня?
if [ -d "$STRATEGY_DIR/current" ]; then
  LAST_OPEN=$(ls -t "$STRATEGY_DIR/current" 2>/dev/null | head -1)
  if [[ "$LAST_OPEN" == *"$DATE"* ]]; then
    echo "  ✓ Day Open уже был сегодня ($LAST_OPEN)"
    echo ""
  fi
fi

# 3. Создание заметки дня
mkdir -p "$STRATEGY_DIR/current"
DAYNOTE="$STRATEGY_DIR/current/day-${DATE}.md"
if [ ! -f "$DAYNOTE" ]; then
  cat > "$DAYNOTE" << EOF
# День: $DATE (Неделя $WEEK_NUM)

## Цели на сегодня
1. 

## Заметки


## Итог дня (заполняется в day-close)

EOF
  echo "  ✓ Создан: $DAYNOTE"
else
  echo "  · Заметка дня уже существует"
fi
echo ""

# 4. Проверка: есть ли открытый WeekPlan?
WEEKPLAN="$STRATEGY_DIR/current/week-${WEEK_NUM}-${DATE}.md"
if [ ! -f "$WEEKPLAN" ]; then
  echo "  ⚠ Нет WeekPlan для текущей недели"
  echo "    Создать: bash ~/iwe-platform/scripts/week-close.sh"
else
  echo "  ✓ WeekPlan: $(basename "$WEEKPLAN")"
fi
echo ""

# 5. Проверка dirty-репозиториев
echo "--- Проверка незакоммиченных изменений ---"
for repo in "$IWE_DIR" "$STRATEGY_DIR" "$KNOWLEDGE_DIR"; do
  if [ -d "$repo/.git" ]; then
    DIRTY=$(cd "$repo" && git status --short 2>/dev/null | wc -l)
    if [ "$DIRTY" -gt 0 ]; then
      echo "  ⚠ $(basename "$repo"): $DIRTY незакоммиченных файлов"
    else
      echo "  ✓ $(basename "$repo"): чисто"
    fi
  fi
done

echo ""
echo "=== День открыт ==="}]}
