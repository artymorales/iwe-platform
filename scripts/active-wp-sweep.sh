#!/usr/bin/env bash
# active-wp-sweep.sh — Сводка активных РП для Strategy Session
# Сканирует WP-REGISTRY.md + inbox/, выводит structured summary.
# Запуск: bash ~/iwe-platform/scripts/active-wp-sweep.sh
set -euo pipefail

IWE_DIR="${IWE_DIR:-$HOME/iwe-platform}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"

REGISTRY="$STRATEGY_DIR/docs/WP-REGISTRY.md"
INBOX="$STRATEGY_DIR/inbox"
CURRENT="$STRATEGY_DIR/current"

echo "=== Active WP Sweep: $(date +%Y-%m-%d) ==="
echo ""

# --- 1. Сбор из REGISTRY ---
echo "--- РП из REGISTRY ---"
if [ -f "$REGISTRY" ]; then
  # Чтение секции «Активные» в REGISTRY
  IN_ACTIVE=false
  IN_CLOSED=false
  FOUND=false
  while IFS= read -r line; do
    # Границы секций
    if echo "$line" | grep -qE '^## Активные'; then
      IN_ACTIVE=true; IN_CLOSED=false; continue
    fi
    if echo "$line" | grep -qE '^## (Закрытые|Легенда|Правила)'; then
      IN_ACTIVE=false
    fi
    # Строки таблицы с WP-N
    if [ "$IN_ACTIVE" = true ] && echo "$line" | grep -qE '^\|.*WP-\d+'; then
      echo "$line"
      FOUND=true
    fi
  done < "$REGISTRY"
  if [ "$FOUND" = false ]; then
    echo "  (нет активных РП в REGISTRY)"
    echo ""
  fi
else
  echo "  ⚠ REGISTRY не найден: $REGISTRY"
fi
echo ""

# --- 2. Проверка inbox/ ---
echo "--- Inbox — файлы WP-* ---"
WP_FILES=$(find "$INBOX" -maxdepth 1 -name "WP-*.md" 2>/dev/null | sort)
if [ -n "$WP_FILES" ]; then
  while IFS= read -r f; do
    FILENAME=$(basename "$f")
    # Извлекаем заголовок (первая #-строка после frontmatter)
    TITLE=""
    IN_BODY=false
    while IFS= read -r fl; do
      if [ "$fl" = "---" ] && [ "$IN_BODY" = false ]; then
        IN_BODY=true; continue
      elif [ "$fl" = "---" ] && [ "$IN_BODY" = true ]; then
        IN_BODY=false; continue
      fi
      if [ "$IN_BODY" = false ] && echo "$fl" | grep -qE '^#\s'; then
        TITLE="$fl"; break
      fi
    done < "$f"
    # Статус из frontmatter
    STATUS=$(grep -E '^status:' "$f" | head -1 | awk '{print $2}' || echo "unknown")
    echo "  · $FILENAME | status=$STATUS | $TITLE"
  done <<< "$WP_FILES"
else
  echo "  (нет WP-файлов в inbox)"
fi
echo ""

# --- 3. Текущий WeekPlan ---
echo "--- Текущий WeekPlan ---"
WEEKPLAN_FILE=$(ls -t "$CURRENT/weekplan-*.md" 2>/dev/null | head -1)
if [ -n "$WEEKPLAN_FILE" ]; then
  echo "  📋 $(basename "$WEEKPLAN_FILE")"
  # Показать секцию задач
  IN_TABLE=false
  while IFS= read -r line; do
    if echo "$line" | grep -qE '^\|.*РП\|'; then
      IN_TABLE=true; continue
    fi
    if [ "$IN_TABLE" = true ] && echo "$line" | grep -qE '^\|.*WP-\d+'; then
      echo "    $line"
    fi
    if [ "$IN_TABLE" = true ] && echo "$line" | grep -qE '^$'; then
      IN_TABLE=false
    fi
  done < "$WEEKPLAN_FILE"
else
  echo "  (нет WeekPlan для текущей недели)"
fi
echo ""

# --- 4. Коммиты за последнюю неделю ---
echo "--- Коммиты за 7 дней ---"
for repo in "$IWE_DIR" "$STRATEGY_DIR" "$KNOWLEDGE_DIR"; do
  if [ -d "$repo/.git" ]; then
    REPO_NAME=$(basename "$repo")
    COMMITS=$(cd "$repo" && git log --oneline --since="7 days ago" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$COMMITS" -gt 0 ]; then
      echo "  · $REPO_NAME: $COMMITS коммитов"
      (cd "$repo" && git log --oneline --since="7 days ago" 2>/dev/null)
    else
      echo "  · $REPO_NAME: нет коммитов за 7 дней"
    fi
  fi
done

echo ""
echo "=== Sweep завершён ==="
