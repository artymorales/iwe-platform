#!/usr/bin/env bash
# day-open.sh — Открытие дня в IWE
# Создаёт DayPlan (формальный план дня с РП, слотами, бюджетом).
# В strategy_day — не создаёт DayPlan (план дня в WeekPlan).
# Gate: проверяет Close предыдущего рабочего дня (WP-25).
# Сверка с FMT: protocol open.md §Day Open.
# Запуск: bash ~/iwe-platform/scripts/day-open.sh
set -euo pipefail

IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"
KNOWLEDGE_DIR="${KNOWLEDGE_DIR:-$HOME/ds-knowledge-index}"
DATE=$(date +%Y-%m-%d)
DAY_OF_WEEK=$(date +%u)  # 1=Пн, 7=Вс
WEEK_NUM=$(date +%V)
DAY_NAME=$(date +%A)

# Вспомогательная: предыдущий рабочий день (Пн→Пт, Вт-Сб→вчера, Вс→Пт)
prev_workday() {
  local dow=$DAY_OF_WEEK
  if [ "$dow" -eq 1 ]; then
    # Понедельник → пятница (3 дня назад)
    date -v-3d +%Y-%m-%d 2>/dev/null || date -d '3 days ago' +%Y-%m-%d
  elif [ "$dow" -eq 7 ]; then
    # Воскресенье → пятница (2 дня назад)
    date -v-2d +%Y-%m-%d 2>/dev/null || date -d '2 days ago' +%Y-%m-%d
  else
    # Вт–Сб → вчера
    date -v-1d +%Y-%m-%d 2>/dev/null || date -d '1 day ago' +%Y-%m-%d
  fi
}

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

# 0b. FMT-обновление — удалено (WP-18: ручное управление версиями)
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

# === GATE: Close предыдущего дня (WP-25) ===
PREV_DATE=$(prev_workday)
echo "--- Gate: Close предыдущего рабочего дня ($PREV_DATE) ---"

PREV_DAYPLAN=$(ls -t "$STRATEGY_DIR/current"/dayplan-${PREV_DATE}*.md 2>/dev/null | head -1 || true)
HAS_CLOSE_COMMIT=false

# Проверяем коммиты day-close за предыдущий рабочий день во всех репо
for repo in "$IWE_DIR" "$STRATEGY_DIR" "$KNOWLEDGE_DIR"; do
  if [ -d "$repo/.git" ]; then
    CLOSE_LOG=$(cd "$repo" && git log --since="${PREV_DATE}T00:00" --until="${DATE}T00:00" --oneline --grep="day-close\|close-gate" 2>/dev/null | head -1 || true)
    if [ -n "$CLOSE_LOG" ]; then
      HAS_CLOSE_COMMIT=true
      echo "  ✓ Close найден в $(basename "$repo"): ${CLOSE_LOG:0:60}"
      break
    fi
  fi
done

if [ "$HAS_CLOSE_COMMIT" = false ]; then
  echo "  ⚠ НЕ НАЙДЕН Close за предыдущий рабочий день ($PREV_DATE)"
  echo ""

  if [ -n "$PREV_DAYPLAN" ]; then
    echo "  DayPlan за $PREV_DATE существует: $(basename "$PREV_DAYPLAN")"
    # Проверим, заполнен ли итог
    if grep -q "Итог дня" "$PREV_DAYPLAN" 2>/dev/null && grep -q "Сделано:" "$PREV_DAYPLAN" 2>/dev/null; then
      echo "  … но итог дня не заполнен / Close не выполнен."
    fi
  else
    echo "  DayPlan за $PREV_DATE не найден."
  fi

  echo ""
  echo "  Протокол ОРЗ предписывает: Close → Open."
  echo "  Выбери действие:"
  echo "    1. Закрыть предыдущий день сейчас  → bash ~/iwe-platform/scripts/day-close.sh"
  echo "    2. Принудительно открыть (override) → продолжение"
  echo ""
  echo -n "  Выбор (1/2): "
  read -r CHOICE

  if [ "$CHOICE" = "1" ]; then
    echo ""
    echo "  Запускаю day-close.sh с OVERRIDE_DATE=$PREV_DATE…"
    export OVERRIDE_DATE="$PREV_DATE"
    bash "$IWE_DIR/scripts/day-close.sh" || echo "  ⚠ day-close.sh завершился с ошибкой, продолжаю day-open"
    unset OVERRIDE_DATE
  elif [ "$CHOICE" = "2" ]; then
    echo ""
    echo "  ⚠ Принудительное открытие (override). Фиксирую в лог."
    mkdir -p "$STRATEGY_DIR/inbox"
    echo "$DATE | day-open override: Close $PREV_DATE пропущен" >> "$STRATEGY_DIR/inbox/open-sessions.log"
  else
    echo "  Неверный выбор. Выход."
    exit 1
  fi
else
  echo "  ✓ Предыдущий день закрыт"
fi
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
  echo "  📋 Сегодня strategy_day ($STRATEGY_DAY)"
  echo ""

  # === GATE: Week Close предыдущей недели (WP-25, сверка с FMT) ===
  PREV_WEEK=$((WEEK_NUM - 1))
  echo "  --- Gate: Week Close W${PREV_WEEK} ---"
  HAS_WEEK_CLOSE=false
  for repo in "$IWE_DIR" "$STRATEGY_DIR"; do
    if [ -d "$repo/.git" ]; then
      WC_LOG=$(cd "$repo" && git log --oneline --grep="week-close" 2>/dev/null | head -1 || true)
      if [ -n "$WC_LOG" ]; then
        echo "  ✓ Week Close найден в $(basename "$repo"): ${WC_LOG:0:60}"
        HAS_WEEK_CLOSE=true
        break
      fi
    fi
  done

  if [ "$HAS_WEEK_CLOSE" = false ]; then
    echo "  ⚠ Week Close W${PREV_WEEK} НЕ НАЙДЕН."
    echo "     → Запусти week-close.sh перед стратегической сессией:"
    echo "       bash ~/iwe-platform/scripts/week-close.sh"
    echo ""
    echo "  Продолжить без Week Close? (y/N): "
    read -r WC_CHOICE
    if [ "$WC_CHOICE" != "y" ] && [ "$WC_CHOICE" != "Y" ]; then
      echo "  Выход. Сначала закрой неделю."
      exit 1
    fi
    echo "  ⚠ Продолжаю без Week Close (override)"
  fi

  echo ""
  echo "     → Выполни §2 strategy-protocol.md (session-prep):"
  echo "       чтение итогов, разбор inbox, проверка НЭП, active-wp-sweep"
  echo "     → Сформируй черновик WeekPlan (status: draft)"
  echo "     → Предложи пользователю начать стратегическую сессию"
  echo ""
  echo "=== День открыт (strategy_day) ==="
  exit 0
fi

# 5. Проверка: читаем последний DayPlan, WeekPlan, WP-REGISTRY (сверка с FMT open.md §3)
echo "--- Контекст планирования (FMT open.md §3) ---"
LAST_DAYPLAN=$(ls -t "$STRATEGY_DIR/current"/dayplan-*.md 2>/dev/null | grep -v "$DATE" | head -1 || true)
if [ -n "$LAST_DAYPLAN" ]; then
  echo "  Последний DayPlan: $(basename "$LAST_DAYPLAN")"
else
  echo "  Последний DayPlan: не найден"
fi

WP_REGISTRY="$STRATEGY_DIR/docs/WP-REGISTRY.md"
if [ -f "$WP_REGISTRY" ]; then
  ACTIVE_WP=$(grep -c '🔄' "$WP_REGISTRY" 2>/dev/null || echo "0")
  echo "  WP-REGISTRY: активно $(echo "$ACTIVE_WP" | tr -d ' ') РП"
else
  echo "  WP-REGISTRY: не найден"
fi
echo ""

# 6. Создание DayPlan
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

# 7. Study Pipeline: предложить материал из очереди
echo "--- Study Pipeline: очередь материалов ---"
READING_LIST="$KNOWLEDGE_DIR/inbox/reading-list.md"
if [ -f "$READING_LIST" ]; then
  # Извлекаем строки очереди (⏳ queue)
  QUEUE_COUNT=$(grep -c '⏳ queue' "$READING_LIST" 2>/dev/null || echo "0")
  echo "  Материалов в очереди: $QUEUE_COUNT"

  if [ "$QUEUE_COUNT" -gt 0 ]; then
    echo ""
    echo "  Доступные материалы для слота «Мышление письмом»:"
    echo ""
    # Парсим и показываем таблицу (колонки: Статус, P, Название, Домен, Источник, Время, TTL)
    grep '⏳ queue' "$READING_LIST" | while IFS='|' read -r _ status pri title domain source time added ttl rest; do
      pri=$(echo "$pri" | xargs)
      title=$(echo "$title" | xargs)
      domain=$(echo "$domain" | xargs)
      time_est=$(echo "$time" | xargs)
      ttl_val=$(echo "$ttl" | xargs)
      echo "    ${pri} ${title} [${domain}] ~${time_est} (TTL: ${ttl_val})"
    done
    echo ""
    echo "  Метод: выбрать → изучить → пересказ → capture.sh → archived"
    echo "  Протокол: memory/protocols/study-pipeline.md (WP-31)"

    # Авто-предложение для DayPlan: если TTL истекает на этой неделе → пометить 🔴
    CURRENT_WEEK="W$WEEK_NUM"
    URGENT=$(grep '⏳ queue' "$READING_LIST" | grep "${CURRENT_WEEK}" | wc -l | tr -d ' ' || echo "0")
    if [ "$URGENT" -gt 0 ]; then
      echo "  ⚠ ${URGENT} материал(ов) с TTL на этой неделе (${CURRENT_WEEK}) — приоритет для сегодняшнего слота"
    fi
  else
    echo "  ⚠ Очередь пуста. Н13: «недостаточный входящий поток». Добавь материал."
  fi
else
  echo "  ⚠ reading-list.md не найден"
fi
echo ""

# 8. Проверка dirty-репозиториев
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
echo "=== День открыт ==="
echo ""
echo "AGENT: Прочитай WeekPlan на эту неделю, последний DayPlan и WP-REGISTRY."
echo "Заполни DayPlan на сегодня: (1) слоты с основной задачей из WeekPlan,"
echo "(2) 📖 Систематическое медленное чтение — ежедневный ритуал (из Study Pipeline),"
echo "(3) 🇬🇧 Английский — ежедневный ритуал."
echo "Предложи пользователю готовый план. Не жди явной команды «составь план»."}]}
