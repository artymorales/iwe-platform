#!/bin/bash
# wp-new — Создание нового РП (Work Package) в 4 местах
# Использование: bash ~/iwe-platform/scripts/skills/wp-new.sh <название> <приоритет> <репозиторий>
#
# После вызова агент:
# 1. Определяет номер (max+1 из WP-REGISTRY)
# 2. Добавляет строку в WP-REGISTRY
# 3. Добавляет пункт в WeekPlan
# 4. Создаёт context-файл
# 5. Пишет в session-log

echo "=== wp-new: создание нового РП ==="
echo ""
echo "Агент, сделай:"
echo ""
echo "1. Определи номер: grep последнего WP- в WP-REGISTRY.md → +1"
echo "2. Добавь строку в ~/ds-strategy/docs/WP-REGISTRY.md:"
echo "   | **WP-N** | Название | Приоритет | ⏳ | репозиторий | R1 | on-demand |"
echo "3. Добавь пункт в WeekPlan (~/ds-strategy/current/weekplan-*.md)"
echo "4. Создай context-файл: ~/ds-strategy/inbox/WP-N-context.md"
echo "5. Запиши в session-log: дата | WP-N | pending | модель | описание"
echo ""
echo "Название — существительное-артефакт (не глагол)."
echo "Пример: ✅ «Конвейер capture» ❌ «Сделать capture»"
