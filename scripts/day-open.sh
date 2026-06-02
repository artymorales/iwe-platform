#!/usr/bin/env bash
# day-open.sh — Открытие дня в IWE
# Создаёт DayPlan (формальный план дня с РП, слотами, бюджетом).
# В strategy_day — не создаёт DayPlan (план дня в WeekPlan).
# Запуск: bash ~/iwe-platform/scripts/day-open.sh
set -euo pipefail

IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-$HOME/ds-knowledge-index}"
DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u)  # 1=Пн, 7=Вс
WEEK_NUM=$(date +%V)
DAY_NAME=$(date +%A)

echo "=== Открытие дня: $DATE ==="
echo ""

# 0. Проверка: strategy_day?
RHYTHM_CFG="$IWE_DIR/memory/day-rhythm-config.yaml"
STRATEGY_DAY="monday"
if [ -f "$RHYTHM_CFG" ]; then
  STRATEGY_DAY=$(grep 'strategy_day:' "$RHYTHM_CFG" | awk '{print $2}' | tr -d '"' || echo "monday")
fi

echo "  Ритм: strategy_day=$STRATEGY_DAY, сегодня=$(date +%A)"
echo ""

# 0b. Проверка версии FMT-шаблона
if [ -f "$IWE_DIR/params.yaml" ]; then
  FMT_CHECK=$(grep 'fmt_check_on_open:' "$IWE_DIR/params.yaml" | grep -c 'true' || true)
  if [ "$FMT_CHECK" -gt 0 ]; then
    CHECK_RESULT=0
    bash "$IWE_DIR/scripts/fmt-version-check.sh" --quiet --notify 2>/dev/null && CHECK_RESULT=$? || CHECK_RESULT=$?
    case "$CHECK_RESULT" in
      1)
        NEW_VER=$(cat "$IWE_DIR/.fmt-update-available" 2>/dev/null | head -1 || echo "?")
        echo "  📦 Доступна новая версия FMT: $NEW_VER"
        echo "    bash $IWE_DIR/scripts/fmt-diff.sh — просмотр изменений"
        if [ -f "$IWE_DIR/.fmt-update-changelog.md" ]; then
          echo "    Ченжлог сохранён: $IWE_DIR/.fmt-update-changelog.md"
        fi
        ;;
      2)
        echo "  ⚠ Не удалось проверить версию FMT (ошибка сети или конфига)"
        echo "    Проверь вручную: bash $IWE_DIR/scripts/fmt-version-check.sh"
        ;;
    esac
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
mkdir -p "$STRATEGY_DIR/current"
EXISTING_DAYPLAN=$(ls -t "$STRATEGY_DIR/current"/dayplan-${DATE}*.md 2>/dev/null | head -1 || true)
if [ -n "$EXISTING_DAYPLAN" ]; then
  echo "  ✓ DayPlan уже существует: $(basename "$EXISTING_DAYPLAN")"
  echo ""
  echo "=== День открыт (повторно) ==="
  exit 0
fi

# 3. Проверка WeekPlan на текущую неделю
# Ищем weekplan-W{N} или week-W{N}
WEEKPLANS=$(ls -t "$STRATEGY_DIR/current/" 2>/dev/null | grep -iE "weekplan|week-" | head -3 || true)
HAS_WEEKPLAN=false
if [ -n "$WEEKPLANS" ]; then
  HAS_WEEKPLAN=true
  echo "  ✓ Найден WeekPlan:"
  echo "$WEEKPLANS" | sed 's/^/    /'
fi
echo ""

# 4. Определяем: strategy_day или обычный день?
LOWER_STRAT_DAY=$(echo "$STRATEGY_DAY" | tr '[:upper:]' '[:lower:]')
LOWER_TODAY=$(date +%A | tr '[:upper:]' '[:lower:]')

IS_STRATEGY_DAY=false
if [ "$LOWER_STRAT_DAY" = "$LOWER_TODAY" ]; then
  IS_STRATEGY_DAY=true
fi

if [ "$IS_STRATEGY_DAY" = true ]; then
  echo "  📋 Сегодня strategy_day ($STRATEGY_DAY) — DayPlan НЕ создаётся"
  echo "     План дня уже встроен в WeekPlan (секция «План на понедельник»)"
  echo "     Запустите: стратегическая сессия"
  echo ""
  echo "=== День открыт (strategy_day) ==="
  exit 0
fi

# 5. Создание DayPlan
echo "--- Создание DayPlan ---"
TEMPLATE="$IWE_DIR/memory/templates/dayplan-template.md"
DAYPLAN="$STRATEGY_DIR/current/dayplan-${DATE}.md"

if [ -f "$TEMPLATE" ]; then
  # Подстановка переменных через envsubst или sed
  WEEK_LABEL="W$WEEK_NUM"
  sed -e "s/{{DATE}}/$DATE/g" \
      -e "s/{{WEEK_NUM}}/$WEEK_LABEL/g" \
      "$TEMPLATE" > "$DAYPLAN"
  echo "  ✓ Создан DayPlan: $(basename "$DAYPLAN")"
else
  # Fallback: простой шаблон
  cat > "$DAYPLAN" << EOF
# DayPlan: $DATE (Неделя $WEEK_NUM)

## Задачи на сегодня
| # | РП | Задача | Артефакт | Бюджет | Статус |
|---|-----|--------|----------|--------|--------|
| 1 | | | | | ☐ |

## Итог дня (заполняется в Day Close)

EOF
  echo "  ✓ Создан DayPlan (fallback): $(basename "$DAYPLAN")"
fi
echo ""

# 6. Проверка dirty-репозиториев
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
