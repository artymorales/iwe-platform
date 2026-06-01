#!/usr/bin/env bash
# archive-wp.sh — Архивация завершённого РП
# Перемещает inbox/WP-{N}-*.md → archive/wp-contexts/ и обновляет статус
# Использование: bash ~/iwe-platform/scripts/archive-wp.sh <WP_NUM>
set -euo pipefail

WP_NUM="${1:-}"
STRATEGY_DIR="${STRATEGY_DIR:-$HOME/ds-strategy}"
INBOX="$STRATEGY_DIR/inbox"
ARCHIVE="$STRATEGY_DIR/archive/wp-contexts"

if [[ -z "$WP_NUM" ]]; then
  echo "Использование: $0 <WP_NUM>" >&2
  echo "Пример: $0 3  → архивирует WP-3" >&2
  exit 1
fi

# Убрать префикс WP- если передали
WP_NUM="${WP_NUM#WP-}"

# Найти файл
WP_FILE=$(find "$INBOX" -maxdepth 1 -name "WP-${WP_NUM}-*.md" 2>/dev/null | head -1)

if [[ -z "$WP_FILE" ]]; then
  echo "❌ WP-${WP_NUM}: файл не найден в $INBOX" >&2
  exit 1
fi

FILENAME=$(basename "$WP_FILE")
ARCHIVE_TARGET="$ARCHIVE/$FILENAME"

echo "📦 Архивирую WP-${WP_NUM}: $FILENAME"

mkdir -p "$ARCHIVE"

# Обновить статус в frontmatter: in_progress|active → done
python3 - "$WP_FILE" "$ARCHIVE_TARGET" <<'PYEOF'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
with open(src, "r", encoding="utf-8") as f:
    content = f.read()

lines = content.split("\n")
in_fm = False
fm_closed = False
new_lines = []
for line in lines:
    if line.strip() == "---" and not fm_closed:
        if not in_fm:
            in_fm = True
        else:
            in_fm = False
            fm_closed = True
        new_lines.append(line)
        continue
    if in_fm and re.match(r"^status:\s*(in_progress|active)\s*$", line):
        line = "status: done"
    new_lines.append(line)

with open(dst, "w", encoding="utf-8") as f:
    f.write("\n".join(new_lines))
PYEOF

echo "✅ WP-${WP_NUM} → archive/wp-contexts/$FILENAME"
echo "   Следующий шаг: обновить WP-REGISTRY.md + коммит"
